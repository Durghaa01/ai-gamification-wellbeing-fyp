"""Tests for the companions API endpoints."""
import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.dependencies import message_rate_limiter
from app.models.companion import (
    Companion,
    CompanionMessageIndex,
    CompanionMessageRole,
    CompanionSession,
)
from app.models.user import AppUser


def _auth_headers(user: AppUser) -> dict[str, str]:
    return {"X-User-Id": user.id}


@pytest.mark.asyncio
async def test_list_companions(client: AsyncClient, test_companion: Companion):
    """Test listing all companions."""
    response = await client.get("/api/v1/companions/")
    
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["id"] == test_companion.id
    assert data[0]["name"] == test_companion.name


@pytest.mark.asyncio
async def test_create_companion(client: AsyncClient):
    """Test creating a new companion."""
    payload = {
        "id": "test-coach",
        "persona": "coach",
        "name": "Test Coach",
        "description": "A test coach companion for unit testing",
        "tagline": "Test coach tagline",
        "system_prompt": "You are a test coach.",
        "quick_prompts": ["Test prompt"],
        "ui_config": {"primaryColor": "#0E4F72"}
    }
    
    response = await client.post("/api/v1/companions/", json=payload)
    
    assert response.status_code == 201
    data = response.json()
    assert data["id"] == payload["id"]
    assert data["name"] == payload["name"]
    assert data["persona"] == payload["persona"]


@pytest.mark.asyncio
async def test_create_session(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion
):
    """Test creating a new companion session."""
    payload = {
        "companion_id": test_companion.id,
        "session_id": "test-session-1"
    }
    
    response = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions",
        json=payload,
        headers=_auth_headers(test_user),
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["id"] == "test-session-1"
    assert data["companion_id"] == test_companion.id
    assert data["user_id"] == test_user.id
    assert data["summary"] is None
    assert data["token_count"] == 0
    assert data["latency_ms"] == 0


@pytest.mark.asyncio
async def test_list_user_sessions(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion,
    db_session: AsyncSession
):
    """Test listing user's companion sessions."""
    # First create a session
    session = CompanionSession(
        id="test-session-1",
        user_id=test_user.id,
        companion_id=test_companion.id,
        companion_name=test_companion.name,
        title="Test Session"
    )
    db_session.add(session)
    await db_session.commit()
    
    # Now list sessions
    response = await client.get(
        f"/api/v1/companions/users/{test_user.id}/sessions",
        headers=_auth_headers(test_user),
    )
    
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) == 1
    assert data[0]["id"] == "test-session-1"
    assert data[0]["token_count"] == 0


@pytest.mark.asyncio
async def test_append_message(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion
):
    """Test appending a message to a session (auto-creates session)."""
    payload = {
        "companion_id": test_companion.id,
        "companion_name": test_companion.name,
        "role": "user",
        "content": "I need help with stress management"
    }
    
    response = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions/new-session/messages",
        json=payload,
        headers=_auth_headers(test_user),
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["message"]["role"] == "user"
    assert "stress" in data["message"]["content"].lower()
    assert data["session"]["id"] == "new-session"
    assert data["session"]["message_count"] == 1
    assert data["message"]["token_count"] >= 1
    assert data["message"]["latency_ms"] == 0


@pytest.mark.asyncio
async def test_get_session_detail(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion,
    db_session: AsyncSession
):
    """Test retrieving session detail with messages."""
    from app.db.utils import utcnow
    
    # Create session and messages
    session = CompanionSession(
        id="test-session-detail",
        user_id=test_user.id,
        companion_id=test_companion.id,
        companion_name=test_companion.name,
        title="Detail Test"
    )
    db_session.add(session)
    await db_session.flush()
    
    msg1 = CompanionMessageIndex(
        id=uuid.uuid4(),
        session=session,
        role=CompanionMessageRole.user,
        created_at=utcnow(),
        token_count=4,
        latency_ms=0,
        document_key=f"{session.id}:msg1",
        extra_meta={"content": "Hello companion", "meta_data": {"source": "test"}},
    )
    msg2 = CompanionMessageIndex(
        id=uuid.uuid4(),
        session=session,
        role=CompanionMessageRole.assistant,
        created_at=utcnow(),
        token_count=8,
        latency_ms=120,
        document_key=f"{session.id}:msg2",
        extra_meta={"content": "Hello! How can I help?", "meta_data": None},
    )
    db_session.add_all([msg1, msg2])
    await db_session.commit()
    
    # Fetch session detail
    response = await client.get(
        f"/api/v1/companions/sessions/{session.id}",
        headers=_auth_headers(test_user),
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["session"]["id"] == session.id
    assert len(data["messages"]) == 2
    assert all("token_count" in message for message in data["messages"])


@pytest.mark.asyncio
async def test_update_session(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion,
    db_session: AsyncSession
):
    """Test updating session title and archive status."""
    from app.models.companion import CompanionSession
    
    # Create session
    session = CompanionSession(
        id="test-update-session",
        user_id=test_user.id,
        companion_id=test_companion.id,
        companion_name=test_companion.name,
        title="Original Title"
    )
    db_session.add(session)
    await db_session.commit()
    
    # Update session
    payload = {
        "title": "Updated Title",
        "is_archived": True
    }
    
    response = await client.patch(
        f"/api/v1/companions/sessions/{session.id}",
        json=payload,
        headers=_auth_headers(test_user),
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Updated Title"
    assert data["is_archived"] is True
    assert "summary" in data


@pytest.mark.asyncio
async def test_delete_session(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion,
    db_session: AsyncSession
):
    """Test deleting a companion session."""
    from app.models.companion import CompanionSession
    
    # Create session
    session = CompanionSession(
        id="test-delete-session",
        user_id=test_user.id,
        companion_id=test_companion.id,
        companion_name=test_companion.name,
        title="To Delete"
    )
    db_session.add(session)
    await db_session.commit()
    
    # Delete session
    response = await client.delete(
        f"/api/v1/companions/sessions/{session.id}",
        headers=_auth_headers(test_user),
    )
    
    assert response.status_code == 204
    
    # Verify deletion
    response = await client.get(
        f"/api/v1/companions/sessions/{session.id}",
        headers=_auth_headers(test_user),
    )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_message_count_increment(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion
):
    """Test that message_count increments correctly."""
    session_id = "test-count-session"
    
    # Send first message
    payload1 = {
        "companion_id": test_companion.id,
        "companion_name": test_companion.name,
        "role": "user",
        "content": "First message"
    }
    
    response1 = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions/{session_id}/messages",
        json=payload1,
        headers=_auth_headers(test_user),
    )
    assert response1.status_code == 201
    assert response1.json()["session"]["message_count"] == 1
    
    # Send second message
    payload2 = {
        "companion_id": test_companion.id,
        "companion_name": test_companion.name,
        "role": "assistant",
        "content": "Reply to first message"
    }
    
    response2 = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions/{session_id}/messages",
        json=payload2,
        headers=_auth_headers(test_user),
    )
    assert response2.status_code == 201
    assert response2.json()["session"]["message_count"] == 2
    assert response2.json()["session"]["token_count"] >= response1.json()["session"]["token_count"]


@pytest.mark.asyncio
async def test_message_idempotency(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion,
):
    """Ensure duplicate message IDs do not create duplicate records."""
    session_id = "idempotent-session"
    message_id = str(uuid.uuid4())
    payload = {
        "companion_id": test_companion.id,
        "companion_name": test_companion.name,
        "message_id": message_id,
        "role": "user",
        "content": "Testing idempotent write",
        "token_count": 12,
    }

    first = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions/{session_id}/messages",
        json=payload,
        headers=_auth_headers(test_user),
    )
    assert first.status_code == 201
    assert first.json()["session"]["message_count"] == 1

    second = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions/{session_id}/messages",
        json=payload,
        headers=_auth_headers(test_user),
    )
    assert second.status_code == 201
    assert second.json()["session"]["message_count"] == 1
    assert second.json()["message"]["id"] == first.json()["message"]["id"]


@pytest.mark.asyncio
async def test_message_rate_limit(
    client: AsyncClient,
    test_user: AppUser,
    test_companion: Companion,
):
    """Ensure message rate limiter blocks excessive traffic."""
    message_rate_limiter.reset(test_user.id)
    session_id = "rate-limit-session"
    payload = {
        "companion_id": test_companion.id,
        "companion_name": test_companion.name,
        "role": "user",
        "content": "testing limits",
    }

    # Allow up to the configured limit (3 from test env override)
    for _ in range(3):
        response = await client.post(
            f"/api/v1/companions/users/{test_user.id}/sessions/{session_id}/messages",
            json=payload,
            headers=_auth_headers(test_user),
        )
        assert response.status_code == 201

    blocked = await client.post(
        f"/api/v1/companions/users/{test_user.id}/sessions/{session_id}/messages",
        json=payload,
        headers=_auth_headers(test_user),
    )
    assert blocked.status_code == 429
    message_rate_limiter.reset(test_user.id)
