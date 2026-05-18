#!/usr/bin/env bash
# Диагностика и перезапуск auth-api (Postgres + email-relay)
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"

[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

echo "=== smtp.env: escape \$ for docker compose ==="
if [[ -f "$SMTP_FILE" ]]; then
  python3 - "$SMTP_FILE" <<'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
f = re.sub(r"\$(?!\$)", "$$", t)
if f != t:
    open(p, "w", encoding="utf-8").write(f)
    print("Fixed: single $ -> $$ in", p)
else:
    print("OK: no unescaped $ in", p)
PY
else
  echo "MISSING: $SMTP_FILE"
  exit 1
fi

echo ""
echo "=== DATABASE_URL check (inside auth-api container) ==="
db_url=$(docker inspect waypoint-auth-api --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep '^DATABASE_URL=' | cut -d= -f2- || true)
if [[ -n "$db_url" ]]; then
  # hide password between ://user:PASS@ and @host
  safe=$(echo "$db_url" | sed -E 's#(postgres://[^:]+:)[^@]+(@)#\\1***\\2#')
  echo "  $safe"
  if echo "$db_url" | grep -qE 'postgres://[^/]+@[^/]+:[^0-9]'; then
    echo "  WARN: password may contain @ or : — use A-Za-z0-9 only in POSTGRES_PASSWORD"
  fi
fi

echo ""
echo "=== Required keys ==="
for k in POSTGRES_PASSWORD JWT_SECRET OTP_WEBHOOK_SECRET OTP_WEBHOOK_URL; do
  if grep -q "^${k}=" "$SMTP_FILE" 2>/dev/null; then
    v=$(grep "^${k}=" "$SMTP_FILE" | head -1 | cut -d= -f2-)
    if [[ -z "${v// }" || "$v" == *"придумайте"* || "$v" == *"любая-длинная"* ]]; then
      echo "  $k: PLACEHOLDER — edit $SMTP_FILE"
    else
      echo "  $k: set (${#v} chars)"
    fi
  else
    echo "  $k: MISSING"
  fi
done

jwt_len=$(grep "^JWT_SECRET=" "$SMTP_FILE" | head -1 | cut -d= -f2- | wc -c)
if [[ "$jwt_len" -lt 33 ]]; then
  echo ""
  echo "WARN: JWT_SECRET should be at least 32 characters"
fi

echo ""
echo "=== Docker status ==="
docker ps -a --filter name=waypoint --format "table {{.Names}}\t{{.Status}}" || true

echo ""
echo "=== auth-api logs (last 60 lines) ==="
docker logs waypoint-auth-api --tail 60 2>&1 || true

echo ""
echo "=== Restart auth stack ==="
cd "$ECO"
docker compose -f docker-compose.auth.yml --env-file "$SMTP_FILE" up -d --build

echo "Waiting 15s..."
sleep 15
docker ps --filter name=waypoint-auth-api --format "{{.Names}} {{.Status}}"
if curl -fsS http://127.0.0.1:8090/health >/dev/null 2>&1; then
  echo "OK: http://127.0.0.1:8090/health"
else
  echo "FAIL: auth-api still not healthy — check logs above"
  exit 1
fi
