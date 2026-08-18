from __future__ import annotations

from datetime import datetime
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import Select, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.dependencies import (
    enforce_message_rate_limit,
    enforce_session_rate_limit,
    get_current_user,
    get_message_store,
)
from app.db.session import get_session
from app.db.utils import utcnow
from app.models.companion import (
    Companion,
    CompanionMessageRole,
    CompanionSession,
    CompanionMessageIndex,
    CompanionOutboxEvent,
)
from app.models.user import AppUser
from app.schemas.companions import (
    CompanionCreate,
    CompanionMessageRead,
    CompanionMessageUpsert,
    CompanionRead,
    CompanionSessionCreate,
    CompanionSessionDetail,
    CompanionSessionRead,
    CompanionSessionUpdate,
    CompanionMessageResponse,
    serialize_companion,
    serialize_session,
)
from app.services.mongo_message_store import (
    MongoMessageStore,
    MongoNotConfiguredError,
)

logger = logging.getLogger("companions")
router = APIRouter(prefix="/companions", tags=["companions"])


def _ensure_user_access(current: AppUser, path_user_id: str) -> None:
  if current.id != path_user_id:
    raise HTTPException(status_code=403, detail="User mismatch")


def _supports_for_update(session: AsyncSession) -> bool:
  bind = session.get_bind()
  if bind is None:
    return False
  engine = getattr(bind, "sync_engine", bind)
  dialect = getattr(engine, "dialect", None)
  name = getattr(dialect, "name", None)
  return name != "sqlite"


@router.get("/", response_model=list[CompanionRead])
async def list_companions(
    session: AsyncSession = Depends(get_session),
) -> list[CompanionRead]:
  result = await session.execute(select(Companion).order_by(Companion.name))
  return [serialize_companion(item) for item in result.scalars().all()]


@router.post("/", response_model=CompanionRead, status_code=201)
async def create_companion(
    payload: CompanionCreate,
    session: AsyncSession = Depends(get_session),
) -> CompanionRead:
  instance = Companion(**payload.model_dump())
  session.add(instance)
  await session.commit()
  await session.refresh(instance)
  return serialize_companion(instance)


@router.post(
    "/users/{user_id}/sessions",
    response_model=CompanionSessionRead,
    status_code=201,
)
async def create_session(
    user_id: str,
    payload: CompanionSessionCreate,
    session: AsyncSession = Depends(get_session),
    current_user: AppUser = Depends(get_current_user),
    _: None = Depends(enforce_session_rate_limit),
) -> CompanionSessionRead:
  _ensure_user_access(current_user, user_id)
  existing_stmt = select(CompanionSession).where(
      CompanionSession.user_id == user_id,
      CompanionSession.companion_id == payload.companion_id,
  )
  result = await session.execute(existing_stmt)
  existing = result.scalar_one_or_none()
  if existing:
    logger.info(
        "companion.session_reused",
        extra={"user_id": user_id, "session_id": existing.id},
    )
    return serialize_session(existing)
  companion = await session.get(Companion, payload.companion_id)
  if not companion:
    raise HTTPException(status_code=404, detail="Companion not found")
  instance = CompanionSession(
      id=payload.session_id or uuid.uuid4().hex,
      user_id=user_id,
      companion=companion,
      companion_name=payload.companion_name_override or companion.name,
      title=payload.title or payload.companion_name_override or companion.name,
  )
  session.add(instance)
  await session.commit()
  await session.refresh(instance)
  logger.info(
      "companion.session_created",
      extra={"user_id": user_id, "session_id": instance.id},
  )
  return serialize_session(instance)


@router.get(
    "/users/{user_id}/sessions",
    response_model=list[CompanionSessionRead],
)
async def list_sessions(
    user_id: str,
    limit: int = Query(10, ge=1, le=100),
    offset: int = Query(0, ge=0),
    state: str = Query(
        "active",
        pattern="^(active|archived|all)$",
        description="Filter by archive state.",
    ),
    session: AsyncSession = Depends(get_session),
    current_user: AppUser = Depends(get_current_user),
) -> list[CompanionSessionRead]:
  _ensure_user_access(current_user, user_id)
  stmt: Select[tuple[CompanionSession]] = (
      select(CompanionSession)
      .where(CompanionSession.user_id == user_id)
      .order_by(CompanionSession.last_message_at.desc().nullslast())
      .offset(offset)
      .limit(limit)
  )
  if state == "active":
    stmt = stmt.where(CompanionSession.is_archived.is_(False))
  elif state == "archived":
    stmt = stmt.where(CompanionSession.is_archived.is_(True))
  result = await session.execute(stmt)
  return [serialize_session(item) for item in result.scalars().all()]


@router.get(
    "/sessions/{session_id}",
    response_model=CompanionSessionDetail,
)
async def fetch_session_detail(
    session_id: str,
    limit: int = Query(50, ge=1, le=200),
    before: datetime | None = Query(
        default=None,
        description="Return messages older than this timestamp.",
    ),
    after: datetime | None = Query(
        default=None,
        description="Return messages newer than this timestamp.",
    ),
    session: AsyncSession = Depends(get_session),
    current_user: AppUser = Depends(get_current_user),
    message_store: MongoMessageStore = Depends(get_message_store),
) -> CompanionSessionDetail:
  instance = await session.get(CompanionSession, session_id)
  if not instance:
    raise HTTPException(status_code=404, detail="Session not found")
  if instance.user_id != current_user.id:
    raise HTTPException(status_code=403, detail="Forbidden")
  message_stmt = (
      select(CompanionMessageIndex)
      .where(CompanionMessageIndex.session_id == session_id)
      .order_by(CompanionMessageIndex.created_at.desc())
      .limit(limit)
  )
  if before is not None:
    message_stmt = message_stmt.where(
        CompanionMessageIndex.created_at < before,
    )
  if after is not None:
    message_stmt = message_stmt.where(
        CompanionMessageIndex.created_at > after,
    )
  result = await session.execute(message_stmt)
  entries = list(result.scalars().all())
  document_map = await message_store.fetch_many(
      [entry.document_key for entry in entries],
  )
  entries.reverse()
  return CompanionSessionDetail(
      session=serialize_session(instance),
      messages=[
          _build_message_response(entry, document_map.get(entry.document_key))
          for entry in entries
      ],
  )


@router.post(
    "/users/{user_id}/sessions/{session_id}/messages",
    response_model=CompanionMessageResponse,
    status_code=201,
)
async def append_message_for_user(
    user_id: str,
    session_id: str,
    payload: CompanionMessageUpsert,
    session: AsyncSession = Depends(get_session),
    current_user: AppUser = Depends(get_current_user),
    _: None = Depends(enforce_message_rate_limit),
    message_store: MongoMessageStore = Depends(get_message_store),
) -> CompanionMessageResponse:
  _ensure_user_access(current_user, user_id)
  if payload.message_id:
    existing_stmt = (
        select(CompanionMessageIndex)
        .options(selectinload(CompanionMessageIndex.session))
        .where(CompanionMessageIndex.id == payload.message_id)
    )
    existing_result = await session.execute(existing_stmt)
    existing = existing_result.scalar_one_or_none()
    if existing:
      parent_session = existing.session
      if not parent_session or parent_session.user_id != user_id:
        raise HTTPException(status_code=404, detail="Session not found")
      document = await message_store.fetch_one(existing.document_key)
      return CompanionMessageResponse(
          message=_build_message_response(existing, document),
          session=serialize_session(parent_session),
      )

  stmt = select(CompanionSession).where(CompanionSession.id == session_id)
  if _supports_for_update(session):
    stmt = stmt.with_for_update()
  result = await session.execute(stmt)
  companion_session = result.scalar_one_or_none()
  if companion_session and companion_session.user_id != user_id:
    raise HTTPException(status_code=404, detail="Session not found")
  if not companion_session:
    companion = await session.get(Companion, payload.companion_id)
    if not companion:
      raise HTTPException(status_code=404, detail="Companion not found")
    companion_session = CompanionSession(
        id=session_id,
        user_id=user_id,
        companion=companion,
        companion_name=payload.companion_name or companion.name,
        title=payload.companion_name or companion.name,
        created_at=utcnow(),
        message_count=0,
        token_count=0,
        latency_ms=0,
        summary=payload.session_summary,
        is_archived=False,
    )
    session.add(companion_session)

  now = utcnow()
  token_count = payload.token_count or max(len(payload.content) // 4, 0)
  provided_latency = payload.latency_ms
  latency_ms = provided_latency if provided_latency is not None else 0

  message_uuid = payload.message_id or uuid.uuid4()
  document_key = f"{session_id}:{message_uuid}"
  message_doc = {
      "session_id": session_id,
      "user_id": user_id,
      "companion_id": payload.companion_id,
      "companion_name": companion_session.companion_name,
      "role": payload.role.value,
      "content": payload.content.strip(),
      "meta_data": payload.metadata or {},
      "token_count": token_count,
      "latency_ms": latency_ms,
      "created_at": now.isoformat(),
  }
  if payload.session_summary:
    message_doc["session_summary"] = payload.session_summary.strip()

  index_entry = CompanionMessageIndex(
      id=message_uuid,
      session=companion_session,
      role=payload.role,
      created_at=now,
      token_count=token_count,
      latency_ms=latency_ms,
      document_key=document_key,
      extra_meta={
          "content": message_doc["content"],
          "meta_data": message_doc["meta_data"],
      },
  )
  session.add(index_entry)

  companion_session.message_count += 1
  companion_session.last_message_at = now
  companion_session.token_count = (companion_session.token_count or 0) + token_count
  if payload.session_summary:
    companion_session.summary = payload.session_summary.strip()
  if payload.role == CompanionMessageRole.assistant and provided_latency is not None:
    companion_session.latency_ms = provided_latency

  outbox_event = CompanionOutboxEvent(
      aggregate_id=session_id,
      event_type="companion.message.created",
      payload={"document_key": document_key, "document": message_doc},
  )
  session.add(outbox_event)

  await session.commit()
  await session.refresh(companion_session)
  await session.refresh(index_entry)
  await session.refresh(outbox_event)

  delivered = False
  try:
    await message_store.upsert_message(document_key, message_doc)
    delivered = True
  except MongoNotConfiguredError:
    logger.debug("MongoDB disabled; message stored via outbox only")
  except Exception as exc:  # noqa: BLE001
    logger.warning(
        "companion.message_mongo_write_failed",
        extra={"session_id": session_id, "error": str(exc)},
    )
  if delivered and outbox_event.id:
    outbox_event.processed_at = utcnow()
    await session.commit()

  response_message = _build_message_response(index_entry, message_doc)
  response = CompanionMessageResponse(
      message=response_message,
      session=serialize_session(companion_session),
  )
  logger.info(
      "companion.message_appended",
      extra={
          "user_id": user_id,
          "session_id": session_id,
          "role": payload.role.value,
      },
  )
  return response


@router.patch(
    "/sessions/{session_id}",
    response_model=CompanionSessionRead,
)
async def update_session(
    session_id: str,
    payload: CompanionSessionUpdate,
    session: AsyncSession = Depends(get_session),
    current_user: AppUser = Depends(get_current_user),
) -> CompanionSessionRead:
  instance = await session.get(CompanionSession, session_id)
  if not instance:
    raise HTTPException(status_code=404, detail="Session not found")
  if instance.user_id != current_user.id:
    raise HTTPException(status_code=403, detail="Forbidden")
  mutated = False
  if payload.title is not None:
    instance.title = payload.title.strip() or instance.companion_name
    mutated = True
  if payload.is_archived is not None:
    instance.is_archived = payload.is_archived
    instance.archived_at = utcnow() if payload.is_archived else None
    mutated = True
  if payload.summary is not None:
    instance.summary = payload.summary.strip() or None
    mutated = True
  if payload.token_count is not None:
    instance.token_count = payload.token_count
    mutated = True
  if payload.latency_ms is not None:
    instance.latency_ms = payload.latency_ms
    mutated = True
  if not mutated:
    return serialize_session(instance)
  await session.commit()
  await session.refresh(instance)
  logger.info(
      "companion.session_updated",
      extra={"user_id": instance.user_id, "session_id": session_id},
  )
  return serialize_session(instance)


@router.delete(
    "/sessions/{session_id}",
    status_code=204,
)
async def delete_session(
    session_id: str,
    session: AsyncSession = Depends(get_session),
    current_user: AppUser = Depends(get_current_user),
):
  instance = await session.get(CompanionSession, session_id)
  if not instance:
    return
  if instance.user_id != current_user.id:
    raise HTTPException(status_code=403, detail="Forbidden")
  await session.delete(instance)
  await session.commit()
  logger.info(
      "companion.session_deleted",
      extra={"user_id": current_user.id, "session_id": session_id},
  )


def _build_message_response(
    entry: CompanionMessageIndex,
    document: dict | None,
) -> CompanionMessageRead:
  fallback_meta = entry.extra_meta or {}
  source = document or {}
  content = source.get("content") or fallback_meta.get("content") or ""
  metadata = source.get("meta_data") or fallback_meta.get("meta_data")
  created_at_value = source.get("created_at")
  created_at = _coerce_datetime(created_at_value, entry.created_at)
  return CompanionMessageRead(
      id=entry.id,
      role=entry.role,
      content=content,
      meta_data=metadata,
      token_count=entry.token_count,
      latency_ms=entry.latency_ms,
      created_at=created_at,
  )


def _coerce_datetime(value: object, fallback: datetime) -> datetime:
  if isinstance(value, datetime):
    return value
  if isinstance(value, str) and value:
    try:
      parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
      return parsed
    except ValueError:
      return fallback
  return fallback
