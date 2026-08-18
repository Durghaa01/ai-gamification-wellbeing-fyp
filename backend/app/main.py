from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import companions, journal, chat
from app.core.bootstrap import seed_defaults
from app.core.config import settings
from app.core.logging import setup_logging
from app.core.mongo import close_mongo_client
from app.db.base import Base
from app.db.session import engine, async_session_factory
# Import models so SQLAlchemy metadata is populated before migrations.
from app.models import companion as _companion_models  # noqa: F401
from app.models import journal as _journal_models  # noqa: F401
from app.models import user as _user_models  # noqa: F401
from app.services.mongo_message_store import MongoMessageStore
from app.services.outbox_worker import CompanionOutboxWorker

setup_logging()
app = FastAPI(title=settings.app_name)
app.state.outbox_worker: CompanionOutboxWorker | None = None

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


@app.exception_handler(RequestValidationError)
async def debug_request_validation_exception_handler(request, exc: RequestValidationError):
    # 打印到后端 console，方便你查错
    print(">>> REQUEST VALIDATION ERROR")
    print("errors:", exc.errors())
    print("body:", exc.body)

    # 把完整的错误返回给前端（取代默认的 “Validation error”）
    return JSONResponse(
        status_code=400,
        content={
            "detail": exc.errors(),
            "body": exc.body,
        },
    )


if settings.cors_origins:
  app.add_middleware(
      CORSMiddleware,
      allow_origins=settings.cors_origins,
      allow_credentials=True,
      allow_methods=["*"],
      allow_headers=["*"],
  )

app.include_router(companions.router, prefix=settings.api_v1_prefix)
app.include_router(journal.router, prefix=settings.api_v1_prefix)
app.include_router(chat.router, prefix=settings.api_v1_prefix)


@app.get("/health")
async def health() -> dict[str, str]:
  return {"status": "ok"}


@app.on_event("startup")
async def on_startup() -> None:
  if settings.database_url.startswith("sqlite"):
    async with engine.begin() as conn:
      await conn.run_sync(Base.metadata.create_all)
  await seed_defaults()
  if settings.mongo_enabled:
    store = MongoMessageStore()
    worker = CompanionOutboxWorker(
        async_session_factory,
        store,
        poll_interval=settings.companion_outbox_poll_interval_seconds,
        batch_size=settings.companion_outbox_batch_size,
    )
    await worker.start()
    app.state.outbox_worker = worker


@app.on_event("shutdown")
async def on_shutdown() -> None:
  worker: CompanionOutboxWorker | None = getattr(app.state, "outbox_worker", None)
  if worker:
    await worker.stop()
  await close_mongo_client()
