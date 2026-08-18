#!/usr/bin/env bash
set -euo pipefail

# Ensure database schema is up to date before launching the API.
alembic upgrade head

exec uvicorn app.main:app --host 0.0.0.0 --port 8000
