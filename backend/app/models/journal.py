from __future__ import annotations

import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import (
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship, declared_attr

from app.db.base import Base
from app.db.utils import utcnow

if TYPE_CHECKING:
  from app.models.user import AppUser


class JournalEntry(Base):
  """Journal entry persisted for a user and calendar day."""

  __tablename__ = "journal_entries"  # type: ignore[assignment]
  __table_args__ = (
      UniqueConstraint("user_id", "entry_date", name="uq_journal_user_day"),
  )

  id: Mapped[uuid.UUID] = mapped_column(
      primary_key=True,
      default=uuid.uuid4,
  )
  user_id: Mapped[str] = mapped_column(
      String(64),
      ForeignKey("app_users.id", ondelete="CASCADE"),
      index=True,
  )
  entry_date: Mapped[date] = mapped_column(Date, index=True)
  mood: Mapped[int] = mapped_column(Integer)
  tags: Mapped[list[str]] = mapped_column(ARRAY(String()).with_variant(JSON, 'sqlite'), default=list)
  note: Mapped[str] = mapped_column(Text)

  sentiment_label: Mapped[str] = mapped_column(String(32))
  sentiment_confidence: Mapped[float] = mapped_column(Float)
  sentiment_scores: Mapped[dict | None] = mapped_column(JSONB().with_variant(JSON, 'sqlite'), default=dict)
  sentiment_version: Mapped[str] = mapped_column(String(64))

  risk_level: Mapped[str] = mapped_column(String(32))
  risk_score: Mapped[float] = mapped_column(Float)
  risk_reason: Mapped[str] = mapped_column(String(255))
  risk_triggers: Mapped[list[str]] = mapped_column(ARRAY(String()).with_variant(JSON, 'sqlite'), default=list)
  risk_version: Mapped[str] = mapped_column(String(64))

  created_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True),
      default=utcnow,
  )
  updated_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True),
      default=utcnow,
      onupdate=utcnow,
  )
  user: Mapped["AppUser"] = relationship(back_populates="journal_entries")  # type: ignore[assignment]

  def mood_percent(self) -> float:
    """Heuristic-friendly representation aligning with Flutter charts."""
    base = {1: 92.0, 2: 76.0, 3: 54.0, 4: 30.0, 5: 12.0}
    base_value = base.get(self.mood, 50.0)
    sentiment_shift = (
        (1 if self.sentiment_label == "positive" else -1)
        * (self.sentiment_confidence - 0.5)
        * 20.0
    )
    return max(0.0, min(100.0, base_value + sentiment_shift))
