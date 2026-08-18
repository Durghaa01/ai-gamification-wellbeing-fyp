from __future__ import annotations

from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone
from typing import Deque


class RateLimitExceeded(Exception):
  """Raised when a caller exceeds the configured rate limit."""


class RateLimiter:
  """In-memory per-key rate limiter using a sliding time window."""

  def __init__(self, limit: int, window: timedelta):
    self._limit = limit
    self._window = window
    self._hits: dict[str, Deque[datetime]] = defaultdict(deque)

  def hit(self, key: str) -> None:
    now = datetime.now(timezone.utc)
    entries = self._hits[key]
    while entries and now - entries[0] > self._window:
      entries.popleft()
    if len(entries) >= self._limit:
      raise RateLimitExceeded()
    entries.append(now)

  def reset(self, key: str | None = None) -> None:
    if key is None:
      self._hits.clear()
      return
    self._hits.pop(key, None)
