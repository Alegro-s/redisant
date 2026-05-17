#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p build/web
INTEGRATION_BASE_URL="${1:-http://127.0.0.1:8080}"
flutter build web --release --base-href / --dart-define="INTEGRATION_BASE_URL=$INTEGRATION_BASE_URL"
echo "Done: build/web — use docker compose --profile web or upload to hosting."
