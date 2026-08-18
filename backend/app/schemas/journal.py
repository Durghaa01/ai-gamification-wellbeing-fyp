from __future__ import annotations

from datetime import date, datetime
from typing import TYPE_CHECKING
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

if TYPE_CHECKING:
  from app.models.journal import JournalEntry


class SentimentInsight(BaseModel):
  label: str
  confidence: float
  scores: dict[str, float] | None = None
  version: str


class RiskInsight(BaseModel):
  level: str
  score: float
  reason: str
  triggers: list[str] = Field(default_factory=list)
  version: str


class JournalEntryCreate(BaseModel):
  mood: int = Field(ge=1, le=5)
  tags: list[str] = Field(default_factory=list)
  note: str = Field(min_length=1)
  entry_date: date | None = None
  manual_triggers: list[str] | None = None

  @field_validator("tags")
  @classmethod
  def normalize_tags(cls, value: list[str]) -> list[str]:
    return [tag.strip().lower() for tag in value if tag.strip()]

  @field_validator("manual_triggers")
  @classmethod
  def normalize_manual_triggers(cls, value: list[str] | None) -> list[str] | None:
    if value is None:
      return None
    return [t.strip().lower() for t in value if str(t).strip()]


class JournalEntryRead(BaseModel):
  model_config = ConfigDict(from_attributes=True)

  id: UUID
  user_id: str
  entry_date: date
  mood: int
  tags: list[str]
  note: str
  sentiment: SentimentInsight
  risk: RiskInsight
  mood_percent: float
  created_at: datetime
  updated_at: datetime


def serialize_entry(entry: "JournalEntry") -> JournalEntryRead:
  return JournalEntryRead(
      id=entry.id,
      user_id=entry.user_id,
      entry_date=entry.entry_date,
      mood=entry.mood,
      tags=entry.tags or [],
      note=entry.note,
      sentiment=SentimentInsight(
          label=entry.sentiment_label,
          confidence=entry.sentiment_confidence,
          scores=entry.sentiment_scores,
          version=entry.sentiment_version,
      ),
      risk=RiskInsight(
          level=entry.risk_level,
          score=entry.risk_score,
          reason=entry.risk_reason,
          triggers=entry.risk_triggers or [],
          version=entry.risk_version,
      ),
      mood_percent=entry.mood_percent(),
      created_at=entry.created_at,
      updated_at=entry.updated_at,
  )
