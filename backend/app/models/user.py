from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.utils import utcnow

if TYPE_CHECKING:
  from app.models.companion import CompanionSession
  from app.models.journal import JournalEntry


class AppUser(Base):
  """Minimal user table mirroring the Flutter AppUser identity."""

  __tablename__ = "app_users"

  id: Mapped[str] = mapped_column(String(64), primary_key=True)
  email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
  role: Mapped[str] = mapped_column(String(32), default="user")
  created_at: Mapped[datetime] = mapped_column(
      DateTime(timezone=True),
      default=utcnow,
  )

  journal_entries: Mapped[list["JournalEntry"]] = relationship(
      back_populates="user",
      cascade="all, delete-orphan",
  )
  companion_sessions: Mapped[list["CompanionSession"]] = relationship(
      back_populates="user",
      cascade="all, delete-orphan",
  )
