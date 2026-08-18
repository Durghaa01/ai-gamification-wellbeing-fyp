from __future__ import annotations

from datetime import date, timedelta
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import Select, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.journal import JournalEntry
from app.schemas.journal import JournalEntryCreate, JournalEntryRead, serialize_entry
from app.services.journal_risk import analyse_journal_note

router = APIRouter(prefix="/journal", tags=["journal"])


@router.get(
    "/users/{user_id}/entries",
    response_model=list[JournalEntryRead],
)
async def list_entries(
    user_id: str,
    limit: int = Query(20, ge=1, le=90),
    days: int | None = Query(
        default=None,
        ge=1,
        le=60,
        description="Restrict results to the last N days.",
    ),
    session: AsyncSession = Depends(get_session),
) -> list[JournalEntryRead]:
  stmt: Select[tuple[JournalEntry]] = (
      select(JournalEntry)
      .where(JournalEntry.user_id == user_id)
      .order_by(JournalEntry.entry_date.desc())
      .limit(limit)
  )

  if days is not None:
    lower_bound = date.today() - timedelta(days=days - 1)
    stmt = stmt.where(JournalEntry.entry_date >= lower_bound)

  result = await session.execute(stmt)
  entries = result.scalars().all()
  return [serialize_entry(entry) for entry in entries]


@router.get(
    "/users/{user_id}/entries/{entry_id}",
    response_model=JournalEntryRead,
)
async def get_entry(
    user_id: str,
    entry_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> JournalEntryRead:
  entry = await session.get(JournalEntry, entry_id)
  if not entry or entry.user_id != user_id:
    raise HTTPException(status_code=404, detail="Entry not found")
  return serialize_entry(entry)


@router.post(
    "/users/{user_id}/entries",
    response_model=JournalEntryRead,
    status_code=201,
)
async def upsert_entry(
    user_id: str,
    payload: JournalEntryCreate,
    session: AsyncSession = Depends(get_session),
) -> JournalEntryRead:
  entry_date = payload.entry_date or date.today()

  # 👇 新：传入 session + user_id，并且 await
  analysis = await analyse_journal_note(
      session=session,
      user_id=user_id,
      user_mood=payload.mood,
      note=payload.note,
      tags=payload.tags,
      entry_date=entry_date,
      manual_triggers=payload.manual_triggers,
  )

  stmt = select(JournalEntry).where(
      JournalEntry.user_id == user_id,
      JournalEntry.entry_date == entry_date,
  )
  existing = (await session.execute(stmt)).scalar_one_or_none()

  if existing:
    existing.mood = payload.mood
    existing.tags = payload.tags
    existing.note = payload.note
    existing.sentiment_label = analysis.sentiment.label
    existing.sentiment_confidence = analysis.sentiment.confidence
    existing.sentiment_scores = analysis.sentiment.scores
    existing.sentiment_version = analysis.sentiment.version
    existing.risk_level = analysis.risk.level
    existing.risk_score = analysis.risk.score
    existing.risk_reason = analysis.risk.reason
    existing.risk_triggers = analysis.risk.triggers
    existing.risk_version = analysis.risk.version
    entry = existing
  else:
    entry = JournalEntry(
        user_id=user_id,
        entry_date=entry_date,
        mood=payload.mood,
        tags=payload.tags,
        note=payload.note,
        sentiment_label=analysis.sentiment.label,
        sentiment_confidence=analysis.sentiment.confidence,
        sentiment_scores=analysis.sentiment.scores,
        sentiment_version=analysis.sentiment.version,
        risk_level=analysis.risk.level,
        risk_score=analysis.risk.score,
        risk_reason=analysis.risk.reason,
        risk_triggers=analysis.risk.triggers,
        risk_version=analysis.risk.version,
    )
    session.add(entry)

  try:
    await session.commit()
  except IntegrityError as exc:
    await session.rollback()
    print("INTEGRITY ERROR:", exc)   # 🔥打印真正原因
    raise HTTPException(status_code=400, detail=str(exc))  # 直接回传 error 信息


  await session.refresh(entry)
  return serialize_entry(entry)
