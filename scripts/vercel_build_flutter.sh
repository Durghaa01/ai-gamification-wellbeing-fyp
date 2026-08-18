#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"
FLUTTER_SDK="${FLUTTER_SDK:-/tmp/flutter}"

if [ ! -d "${FLUTTER_SDK}" ]; then
  git clone --depth 1 --branch "${FLUTTER_CHANNEL}" https://github.com/flutter/flutter.git "${FLUTTER_SDK}"
fi

export PATH="${FLUTTER_SDK}/bin:${PATH}"

flutter config --enable-web
flutter pub get

APP_ENV="${APP_ENV:-production}"
JOURNAL_API_BASE="${JOURNAL_API_BASE:-https://api.example.com}"
USE_REMOTE_BACKEND="${USE_REMOTE_BACKEND:-true}"
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_KEY="${SUPABASE_KEY:-}"

flutter build web --release \
  --dart-define=APP_ENV="${APP_ENV}" \
  --dart-define=JOURNAL_API_BASE="${JOURNAL_API_BASE}" \
  --dart-define=USE_REMOTE_BACKEND="${USE_REMOTE_BACKEND}" \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_KEY="${SUPABASE_KEY}"
