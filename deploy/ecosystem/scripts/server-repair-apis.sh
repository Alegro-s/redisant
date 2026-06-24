#!/usr/bin/env bash
# Emergency repair: restart auth + lynx APIs with smtp.env (after bad deploy).
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
ECO="${ECO:-$DEPLOY_ROOT/redik/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }
[[ -f "$SMTP_FILE" ]] || { echo "Missing $SMTP_FILE"; exit 1; }

cd "$ECO"
docker compose --env-file "$SMTP_FILE" -f docker-compose.auth.yml up -d
docker compose --env-file "$SMTP_FILE" -f docker-compose.apis.yml up -d lynx-api waypoint-api

echo "Waiting..."
for i in $(seq 1 45); do
  if curl -fsS http://127.0.0.1:8090/health >/dev/null 2>&1 \
    && curl -fsS http://127.0.0.1:8082/health >/dev/null 2>&1; then
    echo "auth-api OK"
    echo "lynx-api OK"
    exit 0
  fi
  sleep 1
done

echo "Still failing — check logs:"
docker logs waypoint-auth-api --tail 30 2>&1 || true
docker logs waypoint-lynx-api --tail 30 2>&1 || true
exit 1
