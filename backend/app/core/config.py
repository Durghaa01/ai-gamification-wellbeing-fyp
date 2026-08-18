from functools import lru_cache
from pathlib import Path
from typing import List, Any

from pydantic import field_validator, BeforeValidator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing_extensions import Annotated


def parse_cors_origins(v: Any) -> List[str]:
  """Parse CORS origins from various input formats."""
  if v is None:
    return ["*"]
  if isinstance(v, str):
    v = v.strip()
    if not v:
      return ["*"]
    if v.startswith("["):
      try:
        import json
        return json.loads(v)
      except Exception:
        return ["*"]
    return [origin.strip() for origin in v.split(",") if origin.strip()]
  if isinstance(v, (list, tuple)):
    return [item for item in v if isinstance(item, str)]
  return ["*"]


class Settings(BaseSettings):
  """Application configuration loaded from environment variables."""

  app_name: str = "MindWell Companion & Journal API"
  environment: str = "development"
  api_v1_prefix: str = "/api/v1"
  database_url: str = (
      "postgresql+asyncpg://mindwell:mindwell@localhost:5432/mindwell"
  )
  cors_origins: Annotated[List[str], BeforeValidator(parse_cors_origins)] = [
      "http://localhost:5173",
      "http://localhost:8080",
      "https://mhprojapp-9dheoygyl-thisisuniaccs-projects.vercel.app",
      "https://mhprojapp.vercel.app",
  ]
  companion_message_rate_per_minute: int = 60
  companion_session_rate_per_minute: int = 20
  mongo_enabled: bool = False
  mongo_url: str = "mongodb://localhost:27017"
  mongo_database: str = "mindwell"
  mongo_message_collection: str = "companion_messages"
  mongo_session_context_collection: str = "companion_session_contexts"
  companion_outbox_poll_interval_seconds: int = 5
  companion_outbox_batch_size: int = 50
  disable_rate_limiting: bool = False
  gemini_api_key: str | None = None
  llm_provider: str = "ollama"
  ollama_endpoint: str = "http://localhost:11434/api/generate"
  ollama_model: str = "gpt-oss:20b"
  ollama_timeout: float = 120.0
  vertex_project: str = ""
  vertex_location: str = "us-central1"
  vertex_model: str = "gemini-1.5-flash-001"
  vertex_api_endpoint: str = ""
  supabase_url: str = ""
  supabase_jwt_secret: str = ""
  supabase_anon_key: str = ""
  ollama_model_name: str = "gemma:2b"

  model_config = SettingsConfigDict(
      # Resolve to the project-level .env (backend/.env) regardless of cwd
      env_file=str(Path(__file__).resolve().parent.parent.parent / ".env"),
      env_file_encoding="utf-8",
      case_sensitive=False,
      extra="ignore",
  )




@lru_cache
def get_settings() -> Settings:
  return Settings()


settings = get_settings()
