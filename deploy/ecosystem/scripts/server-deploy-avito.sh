#!/usr/bin/env bash
# Deploy YALGSI (AVITO hackathon messenger) on the same VPS as Lynx/Waypoint.
# Usage: sudo bash deploy/ecosystem/scripts/server-deploy-avito.sh
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
AVITO_DIR="${AVITO_DIR:-$PO_ROOT/avito-messenger}"
AVITO_ENV="${AVITO_ENV:-/opt/waypoint/avito.env}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }
[[ -d "$PO_ROOT/.git" ]] || { echo "Missing $PO_ROOT"; exit 1; }

echo "==> Git pull"
git -C "$PO_ROOT" fetch origin
git -C "$PO_ROOT" checkout -f main
git -C "$PO_ROOT" pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
echo "    HEAD: $(git -C "$PO_ROOT" rev-parse --short HEAD)"
chmod +x "$ECO/scripts/"*.sh 2>/dev/null || true

[[ -d "$AVITO_DIR" ]] || { echo "Missing $AVITO_DIR after pull"; exit 1; }

if [[ ! -f "$AVITO_ENV" ]]; then
  if [[ -f "$ECO/avito.env.example" ]]; then
    cp "$ECO/avito.env.example" "$AVITO_ENV"
    echo "Created $AVITO_ENV — EDIT passwords and ADMIN_API_KEY, then re-run."
    exit 1
  fi
  echo "Missing $AVITO_ENV"; exit 1
fi

# Symlink .env for docker compose
ln -sf "$AVITO_ENV" "$AVITO_DIR/.env"

mkdir -p "$AVITO_DIR/data" "$AVITO_DIR/media" "$AVITO_DIR/secrets"
if [[ ! -f "$AVITO_DIR/backend/data/profiles.json" ]]; then
  echo '{}' > "$AVITO_DIR/backend/data/profiles.json"
fi

echo "==> Docker: YALGSI stack (API + Mattermost + Postgres)"
cd "$AVITO_DIR"
docker compose -f docker-compose.prod.yml --env-file "$AVITO_ENV" up -d --build

echo "==> Wait API"
for i in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
    echo "    API OK on :8000"
    break
  fi
  sleep 2
  if [[ "$i" -eq 90 ]]; then
    docker logs aishield-api --tail 50
    exit 1
  fi
done

echo "==> nginx (yalgsi path on waypointclub.ru)"
if [[ -f "$ECO/nginx/includes/yalgsi-locations.conf" ]]; then
  cp -f "$ECO/nginx/includes/yalgsi-locations.conf" /etc/nginx/waypoint-ecosystem/
  if grep -q 'yalgsi-locations' /etc/nginx/waypoint-ecosystem/club-locations.conf 2>/dev/null; then
    echo "    club-locations already includes yalgsi"
  else
  python3 - <<'PY'
from pathlib import Path
p = Path("/etc/nginx/waypoint-ecosystem/club-locations.conf")
text = p.read_text(encoding="utf-8")
needle = "location / {\n    try_files"
insert = "include /etc/nginx/waypoint-ecosystem/yalgsi-locations.conf;\n\n"
if "yalgsi-locations" not in text and needle in text:
    text = text.replace(needle, insert + needle, 1)
    p.write_text(text, encoding="utf-8")
    print("    patched club-locations.conf")
PY
  fi
  if grep -q 'upstream avito_api' "$ECO/nginx/waypoint-ecosystem.conf" 2>/dev/null; then
    cp -f "$ECO/nginx/waypoint-ecosystem.conf" /etc/nginx/sites-available/waypoint-ecosystem.conf 2>/dev/null || true
  fi
  nginx -t && systemctl reload nginx
fi

echo ""
echo "=============================================="
echo "YALGSI (AVITO hack) deployed."
echo "  API (local):  http://127.0.0.1:8000"
echo "  Admin:        https://waypointclub.ru/yalgsi/admin"
echo "  Health/docs:  https://waypointclub.ru/yalgsi/docs"
echo "  Test login:   superadmin / Admin123! (after seed)"
echo ""
echo "Flutter client: set API to https://waypointclub.ru/yalgsi"
echo "=============================================="
