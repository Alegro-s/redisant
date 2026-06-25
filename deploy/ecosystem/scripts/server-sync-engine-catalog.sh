#!/usr/bin/env bash
# Point Lynx API at CDN engine-manifest.json and verify downloads layout.
#   sudo bash deploy/ecosystem/scripts/server-sync-engine-catalog.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"
DOWNLOADS="/srv/lynx-hub/dist/downloads"
MANIFEST_CDN="https://lynx-hub.ru/downloads/engine-manifest.json"
REPO_MANIFEST="$PO_ROOT/Lynx/hub/public/dist/downloads/engine-manifest.json"
# lynx-api reads this path via bind-mount (see docker-compose.apis.yml).
POLICY_MANIFEST_URL="file:///lynx-hub/downloads/engine-manifest.json"

[[ $EUID -eq 0 ]] || { echo "sudo bash $0"; exit 1; }

mkdir -p "$DOWNLOADS/engine"

if [[ -f "$REPO_MANIFEST" ]]; then
  cp -f "$REPO_MANIFEST" "$DOWNLOADS/engine-manifest.json"
  echo "==> Copied engine-manifest.json from repo"
fi
if [[ -d "$PO_ROOT/Lynx/hub/public/dist/downloads/engine" ]]; then
  cp -f "$PO_ROOT/Lynx/hub/public/dist/downloads/engine/"*.lynxengine "$DOWNLOADS/engine/" 2>/dev/null || true
fi

if [[ -f "$DOWNLOADS/engine-manifest.json" ]]; then
  sed -i '1s/^\xEF\xBB\xBF//' "$DOWNLOADS/engine-manifest.json" 2>/dev/null || true
  sed -i 's|https://lynx-hub.ru/dist/downloads/|https://lynx-hub.ru/downloads/|g' \
    "$DOWNLOADS/engine-manifest.json" || true
fi

RECOMMENDED="0.14.0"
if [[ -f "$DOWNLOADS/engine-manifest.json" ]]; then
  rec="$(python3 -c "import json; print(json.load(open('$DOWNLOADS/engine-manifest.json')).get('recommended_version') or '')" 2>/dev/null || true)"
  [[ -n "$rec" ]] && RECOMMENDED="$rec"
fi

POSTGRES_PASSWORD=""
if [[ -f "$SMTP_FILE" ]]; then
  POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' "$SMTP_FILE" | head -1 | cut -d= -f2- | tr -d '\r' || true)"
fi

if [[ -n "$POSTGRES_PASSWORD" ]]; then
  echo "==> Update nexus_engine_policy (manifest_url + recommended)"
  echo "    policy fetch URL (lynx-api file): $POLICY_MANIFEST_URL"
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx waypoint-db; then
    docker exec -i waypoint-db psql -U waypoint -d waypoint -v ON_ERROR_STOP=1 -c \
      "UPDATE nexus_engine_policy SET manifest_url = '${POLICY_MANIFEST_URL}', recommended_version = '${RECOMMENDED}', updated_at = now() WHERE id = 1;"
  else
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U waypoint -d waypoint -v ON_ERROR_STOP=1 -c \
      "UPDATE nexus_engine_policy SET manifest_url = '${POLICY_MANIFEST_URL}', recommended_version = '${RECOMMENDED}', updated_at = now() WHERE id = 1;"
  fi
else
  echo "WARN: POSTGRES_PASSWORD not in $SMTP_FILE — skip DB policy update"
fi

echo "==> Rebuild lynx-api (file:// manifest + downloads volume)"
cd "$ECO"
docker compose --env-file "$SMTP_FILE" -f docker-compose.apis.yml build lynx-api
docker compose --env-file "$SMTP_FILE" -f docker-compose.apis.yml up -d lynx-api

echo "==> Wait lynx-api"
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8082/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "==> Verify"
curl -fsS "http://127.0.0.1:8082/engine/manifest" | head -c 280 || echo "  lynx-api manifest FAIL"
echo ""
curl -fsS "$MANIFEST_CDN" | head -c 120 || echo "  CDN manifest FAIL"
echo ""
ls -la "$DOWNLOADS/engine/"*.lynxengine 2>/dev/null || echo "  (no .lynxengine in $DOWNLOADS/engine yet)"
echo "OK: policy $POLICY_MANIFEST_URL recommended=$RECOMMENDED"
