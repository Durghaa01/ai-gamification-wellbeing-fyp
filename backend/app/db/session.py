from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from app.core.config import settings

# Connection pool configuration for production
if settings.environment == "production":
    engine = create_async_engine(
        settings.database_url,
        future=True,
        echo=False,
        pool_size=20,  # Maximum number of connections
        max_overflow=10,  # Extra connections when pool is full
        pool_recycle=3600,  # Recycle connections after 1 hour
        pool_pre_ping=True,  # Verify connection health before use
    )
else:
    # Development/test: simpler configuration
    engine = create_async_engine(
        settings.database_url,
        future=True,
        echo=settings.environment == "development",
        poolclass=NullPool if "sqlite" in settings.database_url else None,
    )

async_session_factory = async_sessionmaker(
    engine,
    expire_on_commit=False,
    autoflush=False,
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
  async with async_session_factory() as session:
    yield session
