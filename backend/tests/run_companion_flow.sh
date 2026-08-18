#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Starting Docker stack for companion flow test..."
docker compose up -d db api >/dev/null
cleanup() {
  docker compose logs api >/dev/null || true
  docker compose down >/dev/null
}
trap cleanup EXIT

echo "Waiting for API health..."
for _ in {1..30}; do
  if curl -sf http://localhost:8000/health >/dev/null; then
    break
  fi
  sleep 1
done

echo "Seeding integration user..."
docker compose exec db psql -U mindwell -d mindwell -c \
  "INSERT INTO app_users (id, email, role, created_at) VALUES ('integration-user','integration@mindwell.local','user', now()) ON CONFLICT (id) DO NOTHING;" >/dev/null

echo "Running companion lifecycle checks..."
docker compose exec api python - <<'PY'
import asyncio
import httpx

BASE = "http://localhost:8000"
USER_ID = "integration-user"
HEADERS = {"X-User-Id": USER_ID}


async def main() -> None:
  async with httpx.AsyncClient(base_url=BASE, headers=HEADERS, timeout=10.0) as client:
    # Create a session
    session_payload = {"companion_id": "c_listener", "session_id": "integration-session"}
    resp = await client.post("/api/v1/companions/users/integration-user/sessions", json=session_payload)
    resp.raise_for_status()

    # Append a message
    message_payload = {
        "companion_id": "c_listener",
        "companion_name": "Listener",
        "role": "user",
        "content": "Integration test message",
    }
    resp = await client.post(
        "/api/v1/companions/users/integration-user/sessions/integration-session/messages",
        json=message_payload,
    )
    resp.raise_for_status()

    # List sessions
    resp = await client.get("/api/v1/companions/users/integration-user/sessions")
    resp.raise_for_status()
    sessions = resp.json()
    assert any(item["id"] == "integration-session" for item in sessions)

    # Archive session
    resp = await client.patch(
        "/api/v1/companions/sessions/integration-session",
        json={"is_archived": True},
    )
    resp.raise_for_status()

    # Fetch archived list
    resp = await client.get(
        "/api/v1/companions/users/integration-user/sessions",
        params={"state": "archived"},
    )
    resp.raise_for_status()
    archived = resp.json()
    assert any(item["id"] == "integration-session" and item["is_archived"] for item in archived)

    # Delete session
    resp = await client.delete("/api/v1/companions/sessions/integration-session")
    resp.raise_for_status()

asyncio.run(main())
PY

echo "Companion flow test completed successfully."
