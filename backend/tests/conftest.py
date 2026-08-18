"""Pytest configuration and fixtures for backend tests."""
import os
from typing import AsyncGenerator

import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

os.environ.setdefault("COMPANION_MESSAGE_RATE_PER_MINUTE", "3")
os.environ.setdefault("COMPANION_SESSION_RATE_PER_MINUTE", "3")
os.environ.setdefault("MONGO_ENABLED", "false")

from app.db.base import Base
from app.db.session import get_session
from app.main import app
from app.models.user import AppUser
from app.models.companion import Companion
from app.api.dependencies import message_rate_limiter, session_rate_limiter


# Use in-memory SQLite for tests
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def test_engine():
    """Create a test database engine."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(test_engine) -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session."""
    async_session = sessionmaker(
        test_engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with async_session() as session:
        yield session


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """Create a test HTTP client."""
    async def override_get_session():
        yield db_session
    
    app.dependency_overrides[get_session] = override_get_session
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> AppUser:
    """Create a test user."""
    user = AppUser(
        id="test-user-1",
        email="test@mindwell.local",
        role="user"
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def test_companion(db_session: AsyncSession) -> Companion:
    """Create a test companion."""
    companion = Companion(
        id="test-companion-1",
        persona="listener",
        name="Test Listener",
        description="A test companion for unit testing",
        tagline="Test companion tagline",
        system_prompt="You are a test listener.",
        quick_prompts=["Test prompt 1", "Test prompt 2"],
        ui_config={"primaryColor": "#1A3C7A"}
    )
    db_session.add(companion)
    await db_session.commit()
    await db_session.refresh(companion)
    return companion


@pytest_asyncio.fixture(autouse=True)
async def _reset_rate_limits():
    message_rate_limiter.reset()
    session_rate_limiter.reset()
    yield
    message_rate_limiter.reset()
    session_rate_limiter.reset()
