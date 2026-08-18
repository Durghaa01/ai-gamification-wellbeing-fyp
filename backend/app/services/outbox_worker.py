from __future__ import annotations

import asyncio
import logging
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.db.utils import utcnow
from app.models.companion import CompanionOutboxEvent
from app.services.mongo_message_store import (
    MongoMessageStore,
    MongoNotConfiguredError,
)

logger = logging.getLogger("companions.outbox")


class CompanionOutboxWorker:
  """Background worker that drains the outbox table into MongoDB."""

  def __init__(
      self,
      session_factory: async_sessionmaker[AsyncSession],
      message_store: MongoMessageStore,
      *,
      poll_interval: float = 5.0,
      batch_size: int = 50,
  ):
    self._session_factory = session_factory
    self._message_store = message_store
    self._poll_interval = poll_interval
    self._batch_size = batch_size
    self._stop_event = asyncio.Event()
    self._task: asyncio.Task[None] | None = None

  async def start(self) -> None:
    if self._task is not None:
      return
    self._task = asyncio.create_task(self._run(), name="companion-outbox-worker")
    logger.info("companion.outbox_worker_started")

  async def stop(self) -> None:
    self._stop_event.set()
    if self._task is not None:
      await self._task
      self._task = None
    logger.info("companion.outbox_worker_stopped")

  async def _run(self) -> None:
    while not self._stop_event.is_set():
      processed = await self._drain_once()
      if processed == 0:
        try:
          await asyncio.wait_for(self._stop_event.wait(), timeout=self._poll_interval)
        except asyncio.TimeoutError:
          continue

  async def _drain_once(self) -> int:
    if not self._message_store.enabled:
      # Nothing to do if Mongo is not configured.
      await asyncio.sleep(self._poll_interval)
      return 0

    async with self._session_factory() as session:
      stmt = (
          select(CompanionOutboxEvent)
          .where(CompanionOutboxEvent.processed_at.is_(None))
          .order_by(CompanionOutboxEvent.id)
          .limit(self._batch_size)
      )
      result = await session.execute(stmt)
      events = result.scalars().all()
      if not events:
        return 0

      processed = 0
      for event in events:
        payload: dict[str, Any] = event.payload or {}
        document_key = payload.get("document_key")
        document = payload.get("document")
        if not document_key or not document:
          logger.warning(
              "companion.outbox_invalid_payload",
              extra={"event_id": event.id},
          )
          event.processed_at = utcnow()
          continue
        try:
          await self._message_store.upsert_message(document_key, document)
          event.processed_at = utcnow()
          processed += 1
        except MongoNotConfiguredError:
          logger.warning("companion.outbox_mongo_disabled")
          break
        except Exception as exc:  # noqa: BLE001
          logger.warning(
              "companion.outbox_delivery_failed",
              extra={"event_id": event.id, "error": str(exc)},
          )
      await session.commit()
      return processed
