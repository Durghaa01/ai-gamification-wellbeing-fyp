# MindWell Companion & Journal Backend

FastAPI + PostgreSQL backend that powers the Companion chat sessions and Journal flow of the MindWell web app. It mirrors the domain models implemented in Flutter (companions, companion sessions/messages, and journal entries with sentiment + risk analytics) so the front-end can switch from the demo/local store to a persistent service.

## Features

- **Companions** – CRUD store for persona presets (listener, coach, planner, cheerleader) + seed bootstrap on startup.
- **Companion Sessions** – User-scoped session creation, listing, message streaming, and automatic summary counters used by engagement analytics.
- **Journal Entries** – One entry per user per calendar day with upsert semantics, tag storage, and heuristic-based sentiment + risk analysis to match the Flutter UI needs.
- **PostgreSQL-first schema** – Uses arrays and JSONB to keep tag lists, quick prompts, gradient/UI metadata, and message meta compact.
- **Async stack** – FastAPI + SQLAlchemy async engine + asyncpg driver; battle-tested for running behind uvicorn or any ASGI server.
- **Docker support** – `Dockerfile` + `docker-compose.yml` for local dev with Postgres 16.

## Project Layout

```
backend/
├── app/
│   ├── api/routes/           # FastAPI routers for journal & companions
│   ├── core/                 # Settings + bootstrap seeding logic
│   ├── db/                   # SQLAlchemy base + session factory
│   ├── models/               # ORM models for users, journal entries & companions
│   ├── schemas/              # Pydantic DTOs returned over the wire
│   └── services/             # Journal analytics heuristics
├── requirements.txt
├── Dockerfile
├── docker-compose.yml
└── .env.example
```

## Getting Started

### 1. Configure environment

   ```bash
   cd backend
   cp .env.example .env  # adjust DATABASE_URL to point to your Postgres instance
   python3 -m venv .venv && source .venv/bin/activate
   pip install -r requirements.txt
   ```

#### Optional: enable MongoDB hybrid storage

Set the following variables inside `.env` when you want chat transcripts and rich metadata to be persisted in MongoDB while summaries stay in Postgres:

```
MONGO_ENABLED=true
MONGO_URL=mongodb://localhost:27017
MONGO_DATABASE=mindwell
MONGO_MESSAGE_COLLECTION=companion_messages
```

When enabled, the FastAPI app starts an outbox worker that drains the `companion_outbox` table and keeps MongoDB in sync with the relational store.

### Supabase deployment

If you want Supabase to host the managed Postgres instance:

1. Create a Supabase project and copy the pooled Postgres URI (`Project Settings → Database → Connection string → URI`).
2. Set `DATABASE_URL` (and optionally `SHADOW_DATABASE_URL`) inside `.env` to the Supabase URI. For serverless runtimes use the pooled port (`6543`).
3. Apply the schema against Supabase by running Alembic locally:
   ```bash
   DATABASE_URL="postgresql+asyncpg://postgres:<password>@db.<ref>.supabase.co:5432/postgres" alembic upgrade head
   ```
4. Deploy the FastAPI container to your preferred compute host (Render/Fly/Railway). Supabase only provides the data layer, so the FastAPI service still needs a runtime (Dockerfile is already provided).
5. Keep `MONGO_*` values pointed at your MongoDB provider if you run the hybrid store. Supabase focuses solely on Postgres + realtime.

> See `docs/deployment_vercel_supabase.md` for a complete walkthrough that pairs Supabase with a Vercel-hosted Flutter frontend.

### 2. Run the stack with Docker

The compose file brings up Postgres + FastAPI and automatically applies Alembic migrations before the API starts.

```bash
cd backend
cp .env.example .env
# Optional: adjust rate limits/logging
# COMPANION_MESSAGE_RATE_PER_MINUTE=60
# COMPANION_SESSION_RATE_PER_MINUTE=20
# LOG_LEVEL=INFO
# Ensure DATABASE_URL points at the dockerised database:
# DATABASE_URL=postgresql+asyncpg://mindwell:mindwell@db:5432/mindwell

docker compose up -d db api
docker compose logs -f api  # wait for "Application startup complete."
```

Health endpoints:

- API – http://localhost:8000/health
- Swagger – http://localhost:8000/docs
- Postgres – exposed locally on port `5432`

To tail logs or rerun migrations:

```bash
docker compose logs -f api
docker compose exec api alembic upgrade head
```

### 3. (Optional) Pull an Ollama model for the RemoteCompanionApi

Launch the bundled `ollama` service whenever you want real LLM responses instead of the rule-based fallback:

```bash
docker compose --profile llm up -d ollama
docker compose exec ollama ollama pull gpt-oss:20b
```

The Flutter `RemoteCompanionApi` already points to `http://127.0.0.1:11434` (or `10.0.2.2` inside Android emulators), so once the container is up you can simply launch Flutter with `--dart-define=USE_REMOTE_BACKEND=true` to stream real responses.

### 4. Browse Ollama via the Open WebUI Docker extension

When you need a turnkey chat UI to validate prompts/model responses outside of the Flutter app, bring up the optional `open-webui` service that is wired to the same Ollama container:

1. **Start Ollama + Open WebUI**

   ```bash
   docker compose --profile llm up -d ollama open-webui
   ```

   The Open WebUI container waits for Ollama to be reachable on the internal Docker network before starting.

2. **Open the UI**

   Navigate to http://localhost:3210 and sign in (authentication is disabled by default; set `WEBUI_AUTH=true` + `WEBUI_SECRET_KEY` in `docker-compose.yml` if you need it).

3. **Pick the model**

   Use the **Models → Ollama** tab to select/pull the model you fetched in the previous step (for example `gpt-oss:20b`). Requests stay inside the Compose network so no extra tunnelling is required.

4. **Drop custom extensions (optional)**

   Any files you add under `backend/openwebui/extensions/` are bind-mounted into `/app/backend/data/extensions/mindwell` inside the container, so you can version control custom Open WebUI extensions/function plugins next to the rest of the backend code. Follow the upstream extension format (`manifest.yaml`, `main.py`, etc.) and restart the `open-webui` service to reload them.

This workflow gives PMs/QA a Docker Desktop “Open WebUI Extension”-style sandbox while keeping all traffic within the same local network as the MindWell backend.

### 5. Use Vertex AI (Gemini) instead of Ollama

Prefer a managed LLM? Point the companion module at Vertex AI:

1. Ensure the API container can fetch Application Default Credentials (ADC). Mount a service account key via `GOOGLE_APPLICATION_CREDENTIALS` or run on a host with a workload identity. Grant the service account `roles/aiplatform.user`.
2. Set the following in `.env` (or Compose overrides):
   ```
   LLM_PROVIDER=vertex
   VERTEX_PROJECT=<gcp-project-id>
   VERTEX_LOCATION=us-central1         # or your Vertex region
   VERTEX_MODEL=gemini-1.5-flash-001   # choose any available model
   VERTEX_API_ENDPOINT=                # optional override, defaults to https://<location>-aiplatform.googleapis.com
   ```
3. Start the stack as usual. The chat endpoints keep streaming SSE to Flutter, but upstream requests are routed to Vertex AI instead of Ollama.

### 6. Remote deployment with Docker Compose + Ollama

You can run the same stack on a remote VM or bare-metal host to keep FastAPI and Ollama on the same Docker network:

1. **Sync the repo & env vars**
   - Copy this repository to the server.
   - Inside `backend/`, run `cp .env.example .env` and customize secrets (`DATABASE_URL`, `ENVIRONMENT=production`, optional Supabase credentials). Keep `OLLAMA_ENDPOINT` pointing at `http://ollama:11434` so the API container resolves the bundled LLM service.

2. **Launch everything with Compose**
   - From `backend/`, start the services with `docker compose --profile llm up -d db mongo ollama api`. The `ollama` container mounts the `ollama-data` volume (`/root/.ollama`), so pulled models persist between restarts.

3. **Pull the desired model once**
   - Execute `docker compose exec ollama ollama pull gpt-oss:20b` (or another model). Thanks to the volume mount, you only download the weights the first time.

4. **Verify connectivity**
   - `curl http://<host>:8000/health` should return `{"status":"ok"}`.
   - `curl -X POST http://<host>:11434/api/generate -d '{"model":"gpt-oss:20b","prompt":"hello","stream":false}'` checks the Ollama endpoint.
   - Optionally run `./tests/run_companion_flow.sh` locally (pointed at the remote host) for an end-to-end smoke test.

5. **Expose the API**
   - Open/forward port `8000` or place a reverse proxy (nginx/Caddy) in front.
   - Configure the Flutter web build (`JOURNAL_API_BASE`) to hit this public URL and deploy via Vercel as documented.

This approach avoids managing separate infrastructure for inference—Docker keeps everything co-located, while the persistent volume ensures models survive restarts.

### 7. Create demo users (temporary)

   Until the full authentication service is wired up, you can seed user identities directly:

   ```sql
   INSERT INTO app_users (id, email, role)
   VALUES ('user_primary', 'demo@mindwell.local', 'user')
   ON CONFLICT (id) DO NOTHING;
   ```

### 8. Run locally with an existing Postgres

If you prefer not to use Docker, point `DATABASE_URL` back to `localhost` (or your managed instance) before starting uvicorn:

   ```bash
   uvicorn app.main:app --reload
   ```

   On startup, the service will create tables (if needed) and seed the four default companions if they do not exist.

## API Overview

### Health Check

- `GET /health` → `{ "status": "ok" }`

### Companions

| Endpoint | Description |
| --- | --- |
| `GET /api/v1/companions/` | List predefined companions (id, persona, quick prompts, UI config).
| `POST /api/v1/companions/` | Create/update a persona preset (mainly for future admin tooling).
| `POST /api/v1/companions/users/{userId}/sessions` | Open a chat session for a user + persona.
| `GET /api/v1/companions/users/{userId}/sessions` | Return recent sessions with message counts for analytics cards.
| `GET /api/v1/companions/sessions/{sessionId}` | Session detail including ordered message history.
| `POST /api/v1/companions/users/{userId}/sessions/{sessionId}/messages` | Append a user or assistant message (creates the session on first write). Automatically updates message count + `lastMessageAt`.

Payload example for message append:

```json
{
  "role": "user",
  "content": "I feel stretched thin and need grounding",
  "metadata": {"mood": "stretched"}
}
```

### Journal

| Endpoint | Description |
| --- | --- |
| `GET /api/v1/journal/users/{userId}/entries?limit=7` | Latest entries (optionally limited to the last N days).
| `GET /api/v1/journal/users/{userId}/entries/{entryId}` | Specific entry lookup.
| `POST /api/v1/journal/users/{userId}/entries` | Upsert entry for a day (mood 1-5, tags, note, optional `entryDate`). Returns computed sentiment + risk insights.

Request example:

```json
{
  "mood": 3,
  "tags": ["gratitude", "focus"],
  "note": "Felt hopeful after journaling with the Coach companion",
  "entry_date": "2024-05-04"
}
```

Response snippet:

```json
{
  "id": "4fef1b01-...",
  "user_id": "user_primary",
  "entry_date": "2024-05-04",
  "mood": 3,
  "sentiment": {"label": "positive", "confidence": 0.82, "version": "heuristic-v1"},
  "risk": {"level": "low", "score": 22, "triggers": []},
  "mood_percent": 43.2
}
```

## Database Schema

- `app_users` – lightweight identity table mirroring Flutter's `AppUser` (id/email/role). Foreign key target for all user-owned records.
- `companions` – persona metadata (`id`, `persona`, `system_prompt`, `quick_prompts`, `ui_config`).
- `companion_sessions` – per-user conversations with message counters + last timestamps. Foreign key to `companions` + `app_users`.
- `companion_messages` – chronological messages (`role` ∈ {user, assistant, system}) stored with JSONB metadata.
- `journal_entries` – user/day unique entry storing mood, tags (text[]), note, sentiment data, and risk analysis (JSONB + arrays) tied to `app_users`.

## Integration Notes

- Flutter already exposes `JOURNAL_API_BASE` – point it to this FastAPI base URL to fetch/persist real data.
- Launch Flutter with `--dart-define=USE_REMOTE_BACKEND=true` so the `JournalDataService` and `CompanionDataService` swap over to these HTTP endpoints instead of the seeded store.
- Companion analytics expect summarized sessions; use `GET /api/v1/companions/users/{id}/sessions` as the data source for `LocalDataRepository.fetchCompanionSessions` replacement.
- Journal widgets expect a normalized day key and mood percentage; `mood_percent` replicates the heuristic used in the Flutter model so charts stay identical.
- Authentication is not enforced yet (aligns with current demo app). Populate `app_users` records that match the Flutter demo IDs or wire OAuth/JWT once the broader auth story is ready.
- Full ERD + frontend mapping lives in `../docs/companion_journal_erd.md`.

### 6. Testing inside Docker

```bash
docker compose exec api pytest tests/test_companions_api.py
```

This reuses the running API container (with the async engine + Postgres) so companion/journal integration tests execute against the same schema you use in development.

### 7. Companion lifecycle integration test

The repository also provides a Docker-backed smoke test that drives the API over HTTP:

```bash
./tests/run_companion_flow.sh
```

The script boots the stack, waits for `/health`, seeds an integration user inside Postgres, runs a full session/message/archive/delete lifecycle with `httpx`, and tears everything down automatically.
