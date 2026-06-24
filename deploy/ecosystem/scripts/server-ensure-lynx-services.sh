#!/usr/bin/env bash
# Ensure Lynx API + Lynx Cloud Next.js are running (fixes common 502).
# Always uses /opt/waypoint/smtp.env — never run docker compose without it.
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"
CLOUD_DIR="${CLOUD_DIR:-$PO_ROOT/Lynx/cloud}"
SKIP_CLOUD_REBUILD="${SKIP_CLOUD_REBUILD:-0}"

if [[ ! -f "$SMTP_FILE" ]]; then
  echo "ERROR: missing $SMTP_FILE (JWT_SECRET, POSTGRES_PASSWORD, …)" >&2
  exit 1
fi

COMPOSE_ENV=(--env-file "$SMTP_FILE")

echo "==> Docker APIs (with smtp.env)"
cd "$ECO"
docker compose "${COMPOSE_ENV[@]}" -f docker-compose.auth.yml up -d
docker compose "${COMPOSE_ENV[@]}" -f docker-compose.apis.yml up -d lynx-api waypoint-api
docker compose "${COMPOSE_ENV[@]}" -f docker-compose.apis.yml ps

echo "==> Waiting for API health"
for i in $(seq 1 45); do
  if curl -fsS http://127.0.0.1:8090/health >/dev/null 2>&1 \
    && curl -fsS http://127.0.0.1:8082/health >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

lynx_cloud_ok() {
  local html
  html="$(curl -fsS http://127.0.0.1:3001/ 2>/dev/null || true)"
  [[ -n "$html" ]] || return 1
  echo "$html" | grep -qiE 'medical|аккредитац|CRM аккредитации' && return 1
  echo "$html" | grep -qE 'cloud-light|Lynx Cloud' && return 0
  return 1
}

if [[ "$SKIP_CLOUD_REBUILD" == "1" ]]; then
  echo "==> Skip Lynx Cloud rebuild (SKIP_CLOUD_REBUILD=1)"
elif [[ -d "$CLOUD_DIR" ]]; then
  if lynx_cloud_ok; then
    echo "==> Lynx Cloud :3001 already OK"
  else
    echo "==> Lynx Cloud :3001 wrong or down — hard restart"
    bash "$ECO/scripts/server-restart-lynx-cloud.sh"
  fi
fi

echo "==> Health"
curl -fsS http://127.0.0.1:8090/health && echo " auth-api OK" || echo " auth-api FAIL"
curl -fsS http://127.0.0.1:8082/health && echo " lynx-api OK" || echo " lynx-api FAIL"
curl -fsS http://127.0.0.1:3001/ >/dev/null && echo " lynx-cloud OK" || echo " lynx-cloud FAIL"
