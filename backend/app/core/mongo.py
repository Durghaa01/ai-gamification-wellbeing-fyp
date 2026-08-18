from __future__ import annotations

try:  # pragma: no cover
  from pymongo import MongoClient
  from pymongo.collection import Collection
except Exception:  # noqa: BLE001
  MongoClient = None  # type: ignore[assignment]
  Collection = None  # type: ignore[assignment]

from app.core.config import settings

_client: MongoClient | None = None


def get_mongo_client() -> MongoClient | None:
  """Return a cached Mongo client or None when disabled."""
  global _client  # noqa: PLW0603
  if not settings.mongo_enabled or MongoClient is None:
    return None
  if _client is None:
    _client = MongoClient(settings.mongo_url)
  return _client


def get_mongo_collection(name: str) -> Collection | None:
  client = get_mongo_client()
  if client is None or Collection is None:
    return None
  return client[settings.mongo_database][name]


async def close_mongo_client() -> None:
  global _client  # noqa: PLW0603
  if _client is not None:
    _client.close()
    _client = None
