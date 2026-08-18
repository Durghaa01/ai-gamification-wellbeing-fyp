"""Integration tests for Ollama AI service with companion module."""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient, Response

from app.services.ai_service import AIService, AIServiceException
from app.models.companion import CompanionMessage, CompanionMessageRole
from app.db.utils import utcnow


@pytest.fixture
def mock_ollama_response():
    """Mock successful Ollama response."""
    return {
        "model": "gpt-oss:20b",
        "response": "I understand you're feeling stressed. Let's work through this together.",
        "done": True
    }


@pytest.fixture
def mock_ollama_stream_chunks():
    """Mock streaming Ollama response chunks."""
    return [
        '{"response": "I ", "done": false}\n',
        '{"response": "understand ", "done": false}\n',
        '{"response": "you\'re ", "done": false}\n',
        '{"response": "feeling stressed.", "done": false}\n',
        '{"response": "", "done": true}\n',
    ]


@pytest.mark.asyncio
async def test_ai_service_initialization():
    """Test AIService initializes with correct defaults."""
    service = AIService()
    
    assert service.ollama_endpoint == "http://localhost:11434/api/generate"
    assert service.default_model == "gpt-oss:20b"
    assert service.timeout == 120.0
    
    await service.close()


@pytest.mark.asyncio
async def test_build_prompt():
    """Test prompt building from message history."""
    service = AIService()
    
    messages = [
        CompanionMessage(
            role=CompanionMessageRole.user,
            content="I'm feeling stressed",
            created_at=utcnow(),
        ),
        CompanionMessage(
            role=CompanionMessageRole.assistant,
            content="Tell me more about that",
            created_at=utcnow(),
        ),
    ]
    
    prompt = service._build_prompt(
        messages=messages,
        companion_name="Listener",
        system_prompt="You are an empathetic listener."
    )
    
    assert "You are an empathetic listener." in prompt
    assert "User: I'm feeling stressed" in prompt
    assert "Listener: Tell me more about that" in prompt
    assert "Respond in the voice of Listener" in prompt
    
    await service.close()


@pytest.mark.asyncio
async def test_generate_response_success(mock_ollama_response):
    """Test successful non-streaming response generation."""
    service = AIService()
    
    messages = [
        CompanionMessage(
            role=CompanionMessageRole.user,
            content="Help me with stress",
            created_at=utcnow(),
        )
    ]
    
    # Mock httpx client
    mock_response = MagicMock(spec=Response)
    mock_response.json.return_value = mock_ollama_response
    mock_response.raise_for_status = MagicMock()
    
    with patch.object(service._client, 'post', new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_response
        
        result = await service.generate_response(
            messages=messages,
            companion_name="Listener"
        )
        
        assert "I understand you're feeling stressed" in result
        mock_post.assert_called_once()
        
        # Verify payload structure
        call_args = mock_post.call_args
        payload = call_args.kwargs['json']
        assert payload['model'] == "gpt-oss:20b"
        assert payload['stream'] is False
        assert 'prompt' in payload
    
    await service.close()


@pytest.mark.asyncio
async def test_generate_response_stream_success(mock_ollama_stream_chunks):
    """Test successful streaming response generation."""
    service = AIService()
    
    messages = [
        CompanionMessage(
            role=CompanionMessageRole.user,
            content="I need support",
            created_at=utcnow(),
        )
    ]
    
    # Mock streaming response
    async def mock_aiter_lines():
        for chunk in mock_ollama_stream_chunks:
            yield chunk.strip()
    
    mock_stream_response = AsyncMock()
    mock_stream_response.aiter_lines = mock_aiter_lines
    mock_stream_response.raise_for_status = MagicMock()
    mock_stream_response.__aenter__ = AsyncMock(return_value=mock_stream_response)
    mock_stream_response.__aexit__ = AsyncMock(return_value=None)
    
    with patch.object(service._client, 'stream', return_value=mock_stream_response):
        chunks = []
        async for chunk in service.generate_response_stream(
            messages=messages,
            companion_name="Listener"
        ):
            chunks.append(chunk)
        
        full_response = "".join(chunks)
        assert "I understand you're feeling stressed." in full_response
    
    await service.close()


@pytest.mark.asyncio
async def test_generate_response_timeout():
    """Test timeout handling."""
    service = AIService(timeout=0.001)  # Very short timeout
    
    messages = [
        CompanionMessage(
            role=CompanionMessageRole.user,
            content="Test message",
            created_at=utcnow(),
        )
    ]
    
    with patch.object(service._client, 'post', side_effect=Exception("Timeout")):
        with pytest.raises(AIServiceException) as exc_info:
            await service.generate_response(messages, "Listener")
        
        assert "Failed to generate response" in str(exc_info.value)
    
    await service.close()


@pytest.mark.asyncio
async def test_summarize_conversation():
    """Test conversation summarization."""
    service = AIService()
    
    messages = [
        CompanionMessage(
            role=CompanionMessageRole.user,
            content="I'm stressed about work deadlines",
            created_at=utcnow(),
        ),
        CompanionMessage(
            role=CompanionMessageRole.assistant,
            content="Let's break down your tasks together",
            created_at=utcnow(),
        ),
    ]
    
    mock_response = MagicMock(spec=Response)
    mock_response.json.return_value = {
        "response": "User discussed work stress and task management strategies.",
        "done": True
    }
    mock_response.raise_for_status = MagicMock()
    
    with patch.object(service._client, 'post', new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_response
        
        summary = await service.summarize_conversation(messages, max_length=200)
        
        assert "work stress" in summary.lower()
        mock_post.assert_called_once()
    
    await service.close()


@pytest.mark.asyncio
async def test_chat_endpoint_with_ollama(client: AsyncClient, test_user, test_companion, db_session):
    """Test the /chat endpoint integrates with AI service correctly."""
    from app.models.companion import CompanionSession
    
    # Create a session
    session = CompanionSession(
        id="ollama-test-session",
        user_id=test_user.id,
        companion_id=test_companion.id,
        companion_name=test_companion.name,
        title="Ollama Test"
    )
    db_session.add(session)
    await db_session.commit()
    
    # Mock AI service response
    mock_ai_response = "I'm here to help you. Tell me more about what's on your mind."
    
    with patch('app.api.routes.chat.AIService') as MockAIService:
        mock_service_instance = AsyncMock()
        mock_service_instance.generate_response = AsyncMock(return_value=mock_ai_response)
        mock_service_instance.close = AsyncMock()
        MockAIService.return_value = mock_service_instance
        
        payload = {
            "session_id": session.id,
            "user_id": test_user.id,
            "message": "I need help with anxiety",
            "stream": False
        }
        
        response = await client.post("/api/v1/companions/chat", json=payload)
        
        assert response.status_code == 200
        data = response.json()
        assert data["response"] == mock_ai_response
        assert data["session_id"] == session.id
        
        # Verify AI service was called
        mock_service_instance.generate_response.assert_called_once()


@pytest.mark.asyncio
async def test_empty_message_list():
    """Test handling of empty message list."""
    service = AIService()
    
    summary = await service.summarize_conversation([])
    assert summary == ""
    
    await service.close()


@pytest.mark.asyncio  
async def test_custom_model_override():
    """Test custom model can be specified."""
    service = AIService(default_model="custom-model:7b")
    
    assert service.default_model == "custom-model:7b"
    
    messages = [
        CompanionMessage(
            role=CompanionMessageRole.user,
            content="Test",
            created_at=utcnow(),
        )
    ]
    
    mock_response = MagicMock(spec=Response)
    mock_response.json.return_value = {"response": "Test response", "done": True}
    mock_response.raise_for_status = MagicMock()
    
    with patch.object(service._client, 'post', new_callable=AsyncMock) as mock_post:
        mock_post.return_value = mock_response
        
        await service.generate_response(
            messages=messages,
            companion_name="Test",
            model="override-model:13b"
        )
        
        # Verify the override model was used
        call_args = mock_post.call_args
        payload = call_args.kwargs['json']
        assert payload['model'] == "override-model:13b"
    
    await service.close()
