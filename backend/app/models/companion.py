from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy import JSON
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.utils import utcnow

if TYPE_CHECKING:
  from app.models.user import AppUser


class CompanionPersona(str, enum.Enum):
  listener = "listener"
  coach = "coach"
  planner = "planner"
  cheerleader = "cheerleader"


class CompanionMessageRole(str, enum.Enum):
  user = "user"
  assistant = "assistant"
  system = "system"


class Companion(Base):
  __tablename__ = "companions"

  id: Mapped[str] = mapped_column(String(40), primary_key=True)
  name: Mapped[str] = mapped_column(String(100))
  persona: Mapped[CompanionPersona] = mapped_column(Enum(CompanionPersona))
  description: Mapped[str] = mapped_column(Text)
  tagline: Mapped[str] = mapped_column(Text)
  system_prompt: Mapped[str] = mapped_column(Text)
  quick_prompts: Mapped[list[str]] = mapped_column(ARRAY(String()).with_variant(JSON, 'sqlite'), default=list)
  ui_config: Mapped[dict | None] = mapped_column(JSONB().with_variant(JSON, 'sqlite'), default=dict)
  created_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True), default=utcnow
  )

  sessions: Mapped[list["CompanionSession"]] = relationship(
      back_populates="companion",
      cascade="all, delete-orphan",
  )


class CompanionSession(Base):
  __tablename__ = "companion_sessions"
  __table_args__ = (
      UniqueConstraint(
          "user_id",
          "companion_id",
          name="uq_companion_sessions_user_companion",
      ),
  )

  id: Mapped[str] = mapped_column(String(128), primary_key=True)
  user_id: Mapped[str] = mapped_column(
      String(64),
      ForeignKey("app_users.id", ondelete="CASCADE"),
      index=True,
  )
  companion_id: Mapped[str | None] = mapped_column(
      String(40),
      ForeignKey("companions.id", ondelete="SET NULL"),
      nullable=True,
  )
  companion_name: Mapped[str] = mapped_column(String(120))
  title: Mapped[str | None] = mapped_column(
      String(160),
      nullable=True,
  )
  summary: Mapped[str | None] = mapped_column(Text, nullable=True)
  created_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True), default=utcnow
  )
  last_message_at: Mapped[datetime | None] = mapped_column(
      DateTime(timezone=True),
      nullable=True,
  )
  message_count: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  token_count: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  latency_ms: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  is_archived: Mapped[bool] = mapped_column(Boolean, default=False, insert_default=False)
  archived_at: Mapped[datetime | None] = mapped_column(
      DateTime(timezone=True),
      nullable=True,
  )

  companion: Mapped[Companion | None] = relationship(back_populates="sessions")
  messages: Mapped[list["CompanionMessage"]] = relationship(
      back_populates="session",
      cascade="all, delete-orphan",
      order_by="CompanionMessage.created_at",
  )
  user: Mapped["AppUser"] = relationship(back_populates="companion_sessions")
  message_index_entries: Mapped[list["CompanionMessageIndex"]] = relationship(
      back_populates="session",
      cascade="all, delete-orphan",
      order_by="CompanionMessageIndex.created_at",
  )
  metrics: Mapped["CompanionSessionMetrics"] = relationship(
      back_populates="session",
      cascade="all, delete-orphan",
      uselist=False,
  )


class CompanionMessage(Base):
  __tablename__ = "companion_messages"

  id: Mapped[uuid.UUID] = mapped_column(
      primary_key=True,
      default=uuid.uuid4,
  )
  session_id: Mapped[str] = mapped_column(
      ForeignKey("companion_sessions.id", ondelete="CASCADE"),
      index=True,
  )
  role: Mapped[CompanionMessageRole] = mapped_column(
      Enum(CompanionMessageRole),
      default=CompanionMessageRole.user,
  )
  content: Mapped[str] = mapped_column(Text)
  meta_data: Mapped[dict | None] = mapped_column(JSONB().with_variant(JSON, 'sqlite'), default=dict)
  token_count: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  latency_ms: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  created_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True), default=utcnow, index=True
  )

  session: Mapped[CompanionSession] = relationship(back_populates="messages")


class CompanionMessageIndex(Base):
  __tablename__ = "companion_message_index"

  id: Mapped[uuid.UUID] = mapped_column(
      primary_key=True,
      default=uuid.uuid4,
  )
  session_id: Mapped[str] = mapped_column(
      ForeignKey("companion_sessions.id", ondelete="CASCADE"),
      index=True,
  )
  role: Mapped[CompanionMessageRole] = mapped_column(
      Enum(CompanionMessageRole),
      default=CompanionMessageRole.user,
  )
  created_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True),
      default=utcnow,
      index=True,
  )
  token_count: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  latency_ms: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  document_key: Mapped[str] = mapped_column(String(256))
  version: Mapped[int] = mapped_column(Integer, default=1)
  extra_meta: Mapped[dict | None] = mapped_column(JSONB().with_variant(JSON, 'sqlite'), default=dict)

  session: Mapped[CompanionSession] = relationship(back_populates="message_index_entries")


class CompanionSessionMetrics(Base):
  __tablename__ = "companion_session_metrics"

  session_id: Mapped[str] = mapped_column(
      String(128),
      ForeignKey("companion_sessions.id", ondelete="CASCADE"),
      primary_key=True,
  )
  total_latency_ms: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  assistant_turns: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  user_turns: Mapped[int] = mapped_column(Integer, default=0, insert_default=0)
  avg_sentiment: Mapped[float | None] = mapped_column(Float, nullable=True)
  last_summary_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
  tags: Mapped[list[str]] = mapped_column(ARRAY(String()).with_variant(JSON, 'sqlite'), default=list)
  embeddings_ready: Mapped[bool] = mapped_column(Boolean, default=False, insert_default=False)

  session: Mapped[CompanionSession] = relationship(back_populates="metrics")


class CompanionOutboxEvent(Base):
  __tablename__ = "companion_outbox"

  id: Mapped[int] = mapped_column(
      BigInteger().with_variant(Integer, "sqlite"),
      primary_key=True,
      autoincrement=True,
  )
  aggregate_id: Mapped[str] = mapped_column(String(128), index=True)
  event_type: Mapped[str] = mapped_column(String(64))
  payload: Mapped[dict] = mapped_column(JSONB().with_variant(JSON, 'sqlite'), default=dict)
  created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
  processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
