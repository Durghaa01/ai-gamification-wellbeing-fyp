"""AI service for companion chat using Ollama or Vertex AI."""
from __future__ import annotations

import asyncio
import json
from typing import Any, AsyncIterator, Dict, List

import google.auth
import httpx
from google.auth.transport.requests import Request as GoogleAuthRequest

from app.models.companion import CompanionMessage


class AIService:
    """Service for interacting with the configured LLM provider."""

    def __init__(
        self,
        ollama_endpoint: str = "http://localhost:11434/api/generate",
        default_model: str = "gpt-oss:20b",
        timeout: float = 120.0,
        provider: str = "ollama",
        vertex_project: str | None = None,
        vertex_location: str = "us-central1",
        vertex_model: str = "gemini-1.5-flash-001",
        vertex_api_endpoint: str | None = None,
    ):
        self.provider = (provider or "ollama").lower()
        self.ollama_endpoint = ollama_endpoint
        self.default_model = default_model
        self.timeout = timeout
        self.vertex_project = vertex_project
        self.vertex_location = vertex_location
        self.vertex_model = vertex_model
        self.vertex_api_endpoint = vertex_api_endpoint.rstrip("/") if vertex_api_endpoint else None
        self._client = httpx.AsyncClient(timeout=timeout)

    async def close(self):
        """Close the HTTP client."""
        await self._client.aclose()

    def _build_prompt(
        self,
        messages: List[CompanionMessage],
        companion_name: str,
        system_prompt: str | None = None,
    ) -> str:
        """Build a prompt from message history."""
        if system_prompt is None:
            system_prompt = (
                f"You are {companion_name}, an empathetic mental health companion. "
                "Provide supportive, thoughtful responses. Keep a warm, "
                "supportive tone."
            )

        buffer = [system_prompt, "\nConversation:"]

        for msg in messages:
            speaker = "User" if msg.role == "user" else companion_name
            buffer.append(f"{speaker}: {msg.content}")

        buffer.append(
            f"\nRespond in the voice of {companion_name}. "
            "Keep a warm, supportive tone. "
            "Offer a concise answer and end with an open invitation to continue."
        )

        return "\n".join(buffer)

    async def generate_response(
        self,
        messages: List[CompanionMessage],
        companion_name: str,
        system_prompt: str | None = None,
        model: str | None = None,
    ) -> str:
        """Generate a non-streaming response."""
        prompt = self._build_prompt(messages, companion_name, system_prompt)

        if self.provider == "vertex":
            return await self._vertex_generate(prompt, model)

        return await self._ollama_generate(prompt, model, stream=False)

    async def generate_response_stream(
        self,
        messages: List[CompanionMessage],
        companion_name: str,
        system_prompt: str | None = None,
        model: str | None = None,
    ) -> AsyncIterator[str]:
        """Generate a streaming response (SSE)."""
        prompt = self._build_prompt(messages, companion_name, system_prompt)
        if self.provider == "vertex":
            async for chunk in self._vertex_generate_stream(prompt, model):
                yield chunk
            return

        async for chunk in self._ollama_generate(prompt, model, stream=True):
            yield chunk

    async def summarize_conversation(
        self,
        messages: List[CompanionMessage],
        max_length: int = 200,
        model: str | None = None,
    ) -> str:
        """Summarize a list of messages into a concise summary."""
        if not messages:
            return ""

        # Build summarization prompt
        conversation_text = "\n".join(
            [f"{msg.role}: {msg.content}" for msg in messages]
        )

        prompt = (
            f"Summarize the following conversation in {max_length} words or less. "
            "Focus on key topics, emotions, and any important insights or decisions:\n\n"
            f"{conversation_text}\n\n"
            "Summary:"
        )

        if self.provider == "vertex":
            return await self._vertex_generate(prompt, model)

        return await self._ollama_generate(prompt, model, stream=False)

    # ===== Provider-specific helpers ===== #

    async def _ollama_generate(
        self,
        prompt: str,
        model: str | None,
        stream: bool,
    ) -> str | AsyncIterator[str]:
        """Call Ollama for streaming or non-streaming responses."""
        payload = {
            "model": model or self.default_model,
            "prompt": prompt,
            "stream": stream,
        }

        try:
            if stream:

                async def _stream():
                    async with self._client.stream(
                        "POST",
                        self.ollama_endpoint,
                        json=payload,
                    ) as response:
                        response.raise_for_status()

                        async for line in response.aiter_lines():
                            if not line.strip():
                                continue

                            try:
                                data = json.loads(line)
                            except json.JSONDecodeError:
                                # Skip malformed JSON lines
                                continue

                            chunk = data.get("response", "")
                            if chunk:
                                yield chunk

                            if data.get("done", False):
                                break

                return _stream()

            response = await self._client.post(
                self.ollama_endpoint,
                json=payload,
            )
            response.raise_for_status()
            data = response.json()
            return data.get("response", "").strip()
        except httpx.TimeoutException:
            raise AIServiceException("Request to Ollama timed out")
        except httpx.HTTPStatusError as exc:
            raise AIServiceException(
                f"Ollama returned error: {exc.response.status_code}"
            )
        except Exception as exc:
            raise AIServiceException(f"Failed to contact Ollama: {str(exc)}")

    def _vertex_base_url(self) -> str:
        if not self.vertex_project:
            raise AIServiceException(
                "Vertex AI is selected but VERTEX_PROJECT is not configured"
            )
        endpoint = (
            self.vertex_api_endpoint
            or f"https://{self.vertex_location}-aiplatform.googleapis.com"
        )
        return (
            f"{endpoint}/v1/projects/{self.vertex_project}/locations/"
            f"{self.vertex_location}/publishers/google/models"
        )

    async def _vertex_token(self) -> str:
        """Fetch an access token using application default credentials."""

        def _refresh_token() -> str:
            credentials, _ = google.auth.default(
                scopes=["https://www.googleapis.com/auth/cloud-platform"]
            )
            credentials.refresh(GoogleAuthRequest())
            return credentials.token

        return await asyncio.to_thread(_refresh_token)

    def _extract_vertex_text(self, payload: Dict[str, Any]) -> str:
        candidates = payload.get("candidates") or []
        if not candidates:
            return ""
        content = candidates[0].get("content") or {}
        parts = content.get("parts") or []
        text_parts: list[str] = []
        for part in parts:
            if isinstance(part, dict) and "text" in part:
                text_parts.append(part["text"])
        return "".join(text_parts).strip()

    async def _vertex_generate(self, prompt: str, model: str | None) -> str:
        """Invoke Vertex AI with a single prompt."""
        model_name = model or self.vertex_model
        url = f"{self._vertex_base_url()}/{model_name}:generateContent"
        token = await self._vertex_token()
        payload = {
            "contents": [
                {"role": "user", "parts": [{"text": prompt}]},
            ]
        }
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        try:
            response = await self._client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            data = response.json()
            return self._extract_vertex_text(data)
        except httpx.HTTPStatusError as exc:
            detail = exc.response.text
            raise AIServiceException(
                f"Vertex AI returned error {exc.response.status_code}: {detail}"
            )
        except Exception as exc:
            raise AIServiceException(f"Failed to call Vertex AI: {str(exc)}")

    async def _vertex_generate_stream(
        self,
        prompt: str,
        model: str | None,
    ) -> AsyncIterator[str]:
        """Stream responses from Vertex AI (falls back to single chunk if needed)."""
        model_name = model or self.vertex_model
        url = f"{self._vertex_base_url()}/{model_name}:streamGenerateContent"
        token = await self._vertex_token()
        payload = {
            "contents": [
                {"role": "user", "parts": [{"text": prompt}]},
            ]
        }
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

        try:
            async with self._client.stream(
                "POST",
                url,
                headers=headers,
                json=payload,
            ) as response:
                response.raise_for_status()
                async for line in response.aiter_lines():
                    if not line:
                        continue
                    cleaned = line.strip()
                    if not cleaned:
                        continue
                    if cleaned.startswith("data:"):
                        cleaned = cleaned[5:].strip()
                    try:
                        data = json.loads(cleaned)
                    except json.JSONDecodeError:
                        # Vertex streaming may emit keep-alive newlines
                        continue
                    chunk = self._extract_vertex_text(data)
                    if chunk:
                        yield chunk
        except httpx.HTTPStatusError:
            # Fall back to non-streaming call with a single chunk for resiliency
            yield await self._vertex_generate(prompt, model)
        except Exception as exc:
            raise AIServiceException(f"Failed to stream from Vertex AI: {str(exc)}")


class AIServiceException(Exception):
    """Exception raised by AI service."""

    pass
