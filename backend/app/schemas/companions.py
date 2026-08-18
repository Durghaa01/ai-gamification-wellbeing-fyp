from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.models.companion import CompanionMessageRole, CompanionPersona

if TYPE_CHECKING:
  from app.models.companion import Companion as CompanionModel
  from app.models.companion import CompanionSession as CompanionSessionModel


class CompanionBase(BaseModel):
  id: str
  name: str
  persona: CompanionPersona
  description: str
  tagline: str
  system_prompt: str
  quick_prompts: list[str] = Field(default_factory=list)
  ui_config: dict | None = None


class CompanionCreate(BaseModel):
  id: str
  name: str
  persona: CompanionPersona
  description: str
  tagline: str
  system_prompt: str
  quick_prompts: list[str] = Field(default_factory=list)
  ui_config: dict | None = None


class CompanionRead(CompanionBase):
  model_config = ConfigDict(from_attributes=True)
  created_at: datetime


class CompanionSessionCreate(BaseModel):
  companion_id: str
  companion_name_override: str | None = Field(
      default=None,
      description="Optional custom title used when the persona is rebranded in UI.",
      max_length=120,
  )
  session_id: str | None = Field(
      default=None,
      description="Client-supplied identifier (falls back to UUID if omitted).",
  )
  title: str | None = Field(
      default=None,
      description="Optional session title displayed in UI.",
  )


class CompanionSessionRead(BaseModel):
  model_config = ConfigDict(from_attributes=True)
  id: str
  user_id: str
  companion_id: str | None
  companion_name: str
  title: str | None
  summary: str | None = None
  created_at: datetime
  last_message_at: datetime | None
  message_count: int
  token_count: int
  latency_ms: int
  is_archived: bool
  archived_at: datetime | None


class CompanionSessionUpdate(BaseModel):
  title: str | None = Field(default=None, max_length=160)
  is_archived: bool | None = None
  summary: str | None = Field(default=None, max_length=2000)
  token_count: int | None = Field(default=None, ge=0)
  latency_ms: int | None = Field(default=None, ge=0)


class CompanionMessageCreate(BaseModel):
  role: CompanionMessageRole = CompanionMessageRole.user
  content: str = Field(min_length=1, max_length=2000)
  metadata: dict | None = None
  token_count: int | None = Field(default=None, ge=0)
  latency_ms: int | None = Field(default=None, ge=0)
  message_id: UUID | None = Field(
      default=None,
      description="Optional message identifier used for idempotency.",
  )

  @field_validator("metadata")
  @classmethod
  def validate_metadata(cls, value: dict | None) -> dict | None:
    if value is None:
      return value
    if len(value) > 20:
      raise ValueError("metadata supports at most 20 keys")
    return value


class CompanionMessageRead(BaseModel):
  model_config = ConfigDict(from_attributes=True)
  id: UUID
  role: CompanionMessageRole
  content: str
  meta_data: dict | None = None
  token_count: int
  latency_ms: int
  created_at: datetime


class CompanionSessionDetail(BaseModel):
  session: CompanionSessionRead
  messages: list[CompanionMessageRead]


class CompanionMessageUpsert(CompanionMessageCreate):
  companion_id: str
  companion_name: str = Field(max_length=120)
  session_summary: str | None = Field(
      default=None,
      description="Optional rolling summary applied to the session.",
      max_length=2000,
  )


@field_validator("metadata", mode="after")
def validate_metadata(cls, value: dict | None) -> dict | None:
  if value is None:
    return value
  if len(value) > 20:
    raise ValueError("metadata supports at most 20 keys")
  return value


class CompanionMessageResponse(BaseModel):
  message: CompanionMessageRead
  session: CompanionSessionRead


def serialize_companion(model: "CompanionModel") -> CompanionRead:
  return CompanionRead.model_validate(model, from_attributes=True)


def serialize_session(model: "CompanionSessionModel") -> CompanionSessionRead:
  return CompanionSessionRead.model_validate(model, from_attributes=True)
