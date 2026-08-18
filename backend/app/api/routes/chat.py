"""Chat endpoint with AI integration and rate limiting."""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Dict, AsyncGenerator
import asyncio
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.companion import (
    Companion,
    CompanionMessage,
    CompanionMessageRole,
    CompanionSession,
)
from app.services.ai_service import AIService, AIServiceException
from app.core.config import settings
from app.api.dependencies import get_current_user
from app.models.user import AppUser


router = APIRouter(prefix="/companions", tags=["chat"])


# Rate limiting storage (in-memory, replace with Redis in production)
rate_limit_storage: Dict[str, list[datetime]] = {}
RATE_LIMIT_REQUESTS = 20  # requests
RATE_LIMIT_WINDOW = timedelta(minutes=1)  # per minute


class ChatRequest(BaseModel):
    """Request payload for chat endpoint."""

    session_id: str = Field(..., description="Companion session ID")
    user_id: str = Field(..., description="User ID")
    message: str = Field(..., min_length=1, max_length=2000)
    stream: bool = Field(default=True, description="Enable streaming response")
    model: str | None = Field(default=None, description="Override default model")


class ChatResponse(BaseModel):
    """Response from chat endpoint (non-streaming)."""

    message_id: str
    response: str
    session_id: str


class ChatCompletionRequest(BaseModel):
    """Slim request payload for frontend companion module."""

    user_id: str | None = Field(default=None, description="User ID (optional if using auth token)")
    session_id: str = Field(..., description="Companion session ID")
    companion_id: str = Field(..., description="Companion ID")
    companion_name: str = Field(..., description="Companion display name")
    message: str = Field(..., min_length=1, max_length=4000)
    stream: bool = Field(default=True)
    model: str | None = Field(default=None, description="Model override")


def check_rate_limit(user_id: str) -> bool:
    """Check if user has exceeded rate limit."""
    now = datetime.utcnow()
    cutoff = now - RATE_LIMIT_WINDOW

    # Clean old entries
    if user_id in rate_limit_storage:
        rate_limit_storage[user_id] = [
            ts for ts in rate_limit_storage[user_id] if ts > cutoff
        ]
    else:
        rate_limit_storage[user_id] = []

    # Check limit
    if len(rate_limit_storage[user_id]) >= RATE_LIMIT_REQUESTS:
        return False

    # Record this request
    rate_limit_storage[user_id].append(now)
    return True


async def get_ai_service() -> AsyncGenerator[AIService, None]:
    """Dependency to get AI service instance."""
    service = AIService(
        ollama_endpoint=settings.ollama_endpoint,
        default_model=settings.ollama_model,
        timeout=settings.ollama_timeout,
        provider=settings.llm_provider,
        vertex_project=settings.vertex_project or None,
        vertex_location=settings.vertex_location,
        vertex_model=settings.vertex_model,
        vertex_api_endpoint=settings.vertex_api_endpoint or None,
    )
    try:
        yield service
    finally:
        await service.close()


@router.post("/chat", response_model=ChatResponse)
async def chat(
    payload: ChatRequest,
    session: AsyncSession = Depends(get_session),
    ai_service: AIService = Depends(get_ai_service),
) -> ChatResponse | StreamingResponse:
    """
    Chat with an AI companion.
    
    - **session_id**: Companion session ID
    - **user_id**: User ID for rate limiting
    - **message**: User's message
    - **stream**: Enable streaming (SSE) response
    - **model**: Optional model override
    """
    # Rate limiting
    if not check_rate_limit(payload.user_id):
        raise HTTPException(
            status_code=429,
            detail="Rate limit exceeded. Please try again in a minute.",
        )

    # Fetch session
    companion_session = await session.get(CompanionSession, payload.session_id)
    if not companion_session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Verify user owns this session
    if companion_session.user_id != payload.user_id:
        raise HTTPException(status_code=403, detail="Forbidden")

    # Fetch companion details
    companion = await session.get(Companion, companion_session.companion_id)
    if not companion:
        raise HTTPException(status_code=404, detail="Companion not found")

    # Save user message
    user_message = CompanionMessage(
        id=uuid.uuid4(),
        session=companion_session,
        role=CompanionMessageRole.user,
        content=payload.message.strip(),
        created_at=datetime.utcnow(),
    )
    session.add(user_message)

    # Fetch recent message history (last 30 messages for context)
    history_stmt = (
        select(CompanionMessage)
        .where(CompanionMessage.session_id == payload.session_id)
        .order_by(CompanionMessage.created_at.desc())
        .limit(30)
    )
    result = await session.execute(history_stmt)
    history_messages = list(reversed(result.scalars().all()))
    history_messages.append(user_message)  # Include current message

    # Check if summarization is needed (more than 30 messages)
    if len(history_messages) > 30:
        # Get older messages for summarization
        old_messages = history_messages[:20]
        recent_messages = history_messages[20:]

        try:
            summary = await ai_service.summarize_conversation(old_messages)
            # Store summary as system message
            summary_message = CompanionMessage(
                id=uuid.uuid4(),
                session=companion_session,
                role="system",
                content=f"[Previous conversation summary]: {summary}",
                meta_data={"summary": True},
                created_at=datetime.utcnow(),
            )
            session.add(summary_message)
            await session.commit()
            
            # Use summary + recent messages for context
            context_messages = [summary_message] + recent_messages
        except AIServiceException:
            # Fallback: just use recent messages
            context_messages = recent_messages
    else:
        context_messages = history_messages

    # Streaming response
    if payload.stream:
        async def generate_stream():
            full_response = []
            try:
                async for chunk in ai_service.generate_response_stream(
                    messages=context_messages,
                    companion_name=companion.name,
                    system_prompt=companion.system_prompt,
                    model=payload.model,
                ):
                    full_response.append(chunk)
                    # Send SSE formatted chunk
                    yield f"data: {chunk}\n\n"

                # Save assistant message
                assistant_message = CompanionMessage(
                    id=uuid.uuid4(),
                    session=companion_session,
                    role="assistant",
                    content="".join(full_response),
                    created_at=datetime.utcnow(),
                )
                session.add(assistant_message)
                companion_session.message_count += 2  # user + assistant
                companion_session.last_message_at = datetime.utcnow()
                await session.commit()

                # Send completion signal
                yield "data: [DONE]\n\n"

            except AIServiceException as e:
                yield f"data: [ERROR] {str(e)}\n\n"

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "X-Accel-Buffering": "no",
            },
        )

    # Non-streaming response
    try:
        response_text = await ai_service.generate_response(
            messages=context_messages,
            companion_name=companion.name,
            system_prompt=companion.system_prompt,
            model=payload.model,
        )

        # Save assistant message
        assistant_message = CompanionMessage(
            id=uuid.uuid4(),
            session=companion_session,
            role="assistant",
            content=response_text,
            created_at=datetime.utcnow(),
        )
        session.add(assistant_message)
        companion_session.message_count += 2  # user + assistant
        companion_session.last_message_at = datetime.utcnow()
        await session.commit()

        return ChatResponse(
            message_id=str(assistant_message.id),
            response=response_text,
            session_id=payload.session_id,
        )

    except AIServiceException as e:
        raise HTTPException(status_code=502, detail=f"AI service error: {str(e)}")


# ====== Minimal chat-completions bridge for frontend ====== #

def _contains_sensitive(text: str) -> bool:
    lowered = text.lower()
    hotwords = (
        "suicide",
        "kill myself",
        "self-harm",
        "hurt myself",
        "overdose",
        "end my life",
    )
    return any(w in lowered for w in hotwords)


def _sanitize_prompt(text: str) -> str:
    banned = (
        "ignore previous instructions",
        "system override",
        "jailbreak",
        "pretend to be",
    )
    prepared = text
    for phrase in banned:
        prepared = prepared.replace(phrase, "")
    return prepared.strip()


@router.post(
    "/chat-completions",
    response_model=ChatResponse,
    name="Companion chat with backend LLM",
)
async def chat_completions(
    payload: ChatCompletionRequest,
    session: AsyncSession = Depends(get_session),
    ai_service: AIService = Depends(get_ai_service),
    current_user: AppUser = Depends(get_current_user),
) -> ChatResponse | StreamingResponse:
    user_id = current_user.id
    if payload.user_id and payload.user_id != user_id:
        # Enforce the authenticated identity if provided
        raise HTTPException(status_code=403, detail="User mismatch")

    # Ensure companion exists
    companion = await session.get(Companion, payload.companion_id)
    if not companion:
        raise HTTPException(status_code=404, detail="Companion not found")

    # Get or create session
    companion_session = await session.get(CompanionSession, payload.session_id)
    if companion_session and companion_session.user_id != user_id:
        raise HTTPException(status_code=403, detail="Forbidden")
    if not companion_session:
        companion_session = CompanionSession(
            id=payload.session_id,
            user_id=user_id,
            companion=companion,
            companion_name=payload.companion_name or companion.name,
            title=payload.companion_name or companion.name,
            created_at=datetime.utcnow(),
        )
        session.add(companion_session)
        await session.commit()

    prepared_message = _sanitize_prompt(payload.message)

    # Safety stop for high-risk content
    if _contains_sensitive(prepared_message):
        safety_text = (
            "I am really sorry you are feeling this way. Your safety matters. "
            "Please reach out to a trusted person or local emergency service. "
            "In the US, you can call or text 988 for immediate support."
        )
        now = datetime.utcnow()
        user_msg = CompanionMessage(
            id=uuid.uuid4(),
            session=companion_session,
            role=CompanionMessageRole.user,
            content=prepared_message,
            created_at=now,
        )
        assistant_msg = CompanionMessage(
            id=uuid.uuid4(),
            session=companion_session,
            role=CompanionMessageRole.assistant,
            content=safety_text,
            meta_data={"safety": True},
            created_at=now,
        )
        session.add_all([user_msg, assistant_msg])
        companion_session.last_message_at = now
        companion_session.message_count += 2
        await session.commit()
        return ChatResponse(
            message_id=str(assistant_msg.id),
            response=safety_text,
            session_id=payload.session_id,
        )

    # Fetch recent history (last 30 turns)
    history_stmt = (
        select(CompanionMessage)
        .where(CompanionMessage.session_id == payload.session_id)
        .order_by(CompanionMessage.created_at.desc())
        .limit(30)
    )
    result = await session.execute(history_stmt)
    history_messages = list(reversed(result.scalars().all()))

    # Append incoming user message to context
    user_message = CompanionMessage(
        id=uuid.uuid4(),
        session=companion_session,
        role=CompanionMessageRole.user,
        content=prepared_message,
        created_at=datetime.utcnow(),
    )
    session.add(user_message)
    history_messages.append(user_message)

    async def _persist_assistant(content: str, latency_ms: int = 0) -> uuid.UUID:
        assistant_message = CompanionMessage(
            id=uuid.uuid4(),
            session=companion_session,
            role=CompanionMessageRole.assistant,
            content=content,
            latency_ms=latency_ms,
            created_at=datetime.utcnow(),
        )
        session.add(assistant_message)
        companion_session.message_count += 2
        companion_session.last_message_at = datetime.utcnow()
        await session.commit()
        return assistant_message.id

    if payload.stream:
        async def generate():
            chunks: list[str] = []
            try:
                async for chunk in ai_service.generate_response_stream(
                    messages=history_messages,
                    companion_name=companion.name,
                    system_prompt=companion.system_prompt,
                    model=payload.model,
                ):
                    chunks.append(chunk)
                    yield f"data: {chunk}\n\n"
                message_id = await _persist_assistant("".join(chunks))
                yield f"data: [DONE] {message_id}\n\n"
            except AIServiceException as exc:
                yield f"data: [ERROR] {str(exc)}\n\n"

        return StreamingResponse(
            generate(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "X-Accel-Buffering": "no",
            },
        )

    # Non-streaming path
    try:
        reply_text = await ai_service.generate_response(
            messages=history_messages,
            companion_name=companion.name,
            system_prompt=companion.system_prompt,
            model=payload.model,
        )
        message_id = await _persist_assistant(reply_text)
        return ChatResponse(
            message_id=str(message_id),
            response=reply_text,
            session_id=payload.session_id,
        )
    except AIServiceException as exc:
        raise HTTPException(status_code=502, detail=f"AI service error: {exc}")
