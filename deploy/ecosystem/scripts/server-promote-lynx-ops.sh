#!/usr/bin/env bash
# Promote Lynx ops users and run analytics migration.
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
SMTP_FILE="${SMTP_FILE:-/opt/waypoint/smtp.env}"
MIGRATION="$PO_ROOT/platform/server/migrations/20260623120000_lynx_analytics_storage.sql"
DB_URL="${DATABASE_URL:-}"

if [[ -z "$DB_URL" ]]; then
  POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' "$SMTP_FILE" 2>/dev/null | cut -d= -f2- || true)"
  if [[ -n "$POSTGRES_PASSWORD" ]]; then
    DB_URL="postgres://waypoint:${POSTGRES_PASSWORD}@127.0.0.1:5432/waypoint"
  else
    DB_URL="postgres://waypoint:WaypointProdChangeMe2026xK9@127.0.0.1:5432/waypoint"
  fi
fi

[[ -f "$MIGRATION" ]] || { echo "Missing $MIGRATION"; exit 1; }

if docker ps --format '{{.Names}}' | grep -qx waypoint-db; then
  docker exec -i waypoint-db psql -U waypoint -d waypoint < "$MIGRATION"
else
  psql "$DB_URL" -f "$MIGRATION"
fi

echo "OK: lynx analytics tables + rozalityai@gmail.com -> nexus (if user exists)"
