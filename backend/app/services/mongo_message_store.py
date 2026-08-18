from __future__ import annotations

import asyncio
from collections.abc import Mapping, Sequence
from datetime import datetime
from typing import Any

try:  # pragma: no cover - optional dependency
  from pymongo.collection import Collection
except Exception:  # noqa: BLE001
  Collection = None  # type: ignore[assignment]

from app.core.config import settings
from app.core.mongo import get_mongo_collection


class MongoNotConfiguredError(RuntimeError):
  """Raised when a Mongo operation is attempted without configuration."""


class MongoMessageStore:
  """Small helper around the Mongo collection that stores companion messages."""

  def __init__(self, collection_name: str | None = None):
    self._collection_name = collection_name or settings.mongo_message_collection

  @property
  def enabled(self) -> bool:
    return get_mongo_collection(self._collection_name) is not None

  def _collection(self) -> Collection | None:
    if Collection is None:
      return None
    return get_mongo_collection(self._collection_name)

  async def upsert_message(
      self,
      document_key: str,
      payload: Mapping[str, Any],
  ) -> None:
    collection = self._collection()
    if collection is None:
      raise MongoNotConfiguredError("MongoDB is disabled")
    document = dict(payload)
    created_at = document.get("created_at")
    if isinstance(created_at, str):
      try:
        document["created_at"] = datetime.fromisoformat(
            created_at.replace("Z", "+00:00"),
        )
      except ValueError:
        document.pop("created_at", None)
    document["_id"] = document_key

    def _update() -> None:
      collection.update_one(
          {"_id": document_key},
          {"$set": document},
          upsert=True,
      )

    await asyncio.to_thread(_update)

  async def fetch_many(
      self,
      document_keys: Sequence[str],
  ) -> dict[str, dict[str, Any]]:
    if not document_keys:
      return {}
    collection = self._collection()
    if collection is None:
      return {}

    def _fetch() -> dict[str, dict[str, Any]]:
      results: dict[str, dict[str, Any]] = {}
      for doc in collection.find({"_id": {"$in": list(document_keys)}}):
        results[str(doc["_id"])] = doc
      return results

    return await asyncio.to_thread(_fetch)

  async def fetch_one(self, document_key: str) -> dict[str, Any] | None:
    collection = self._collection()
    if collection is None:
      return None

    return await asyncio.to_thread(collection.find_one, {"_id": document_key})


async def get_mongo_message_store() -> MongoMessageStore:
  """FastAPI dependency helper."""
  return MongoMessageStore()
