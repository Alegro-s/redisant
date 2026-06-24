#!/usr/bin/env bash
# Ensure Lynx API + Lynx Cloud Next.js are running (fixes common 502).
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
CLOUD_DIR="${CLOUD_DIR:-$PO_ROOT/Lynx/cloud}"

echo "==> Docker APIs"
cd "$ECO"
docker compose -f docker-compose.auth.yml up -d
docker compose -f docker-compose.apis.yml up -d lynx-api waypoint-api
docker compose -f docker-compose.apis.yml ps

echo "==> Lynx Cloud :3001"
if [[ -d "$CLOUD_DIR" ]]; then
  cd "$CLOUD_DIR"
  if [[ ! -d node_modules ]]; then npm ci; fi
  npm run build
  pkill -f "next start.*3001" 2>/dev/null || true
  sleep 1
  nohup npm run start -- -H 0.0.0.0 -p 3001 >>/var/log/lynx-cloud.log 2>&1 &
  sleep 2
fi

echo "==> Health"
curl -fsS http://127.0.0.1:8082/health && echo " lynx-api OK" || echo " lynx-api FAIL"
curl -fsS http://127.0.0.1:3001/ >/dev/null && echo " lynx-cloud OK" || echo " lynx-cloud FAIL"
