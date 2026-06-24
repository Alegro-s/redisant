#!/usr/bin/env bash
# Hard restart Lynx Cloud Next.js on :3001 (next-server often survives pkill).
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
CLOUD_DIR="${CLOUD_DIR:-$PO_ROOT/Lynx/cloud}"
SKIP_BUILD="${SKIP_BUILD:-0}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }
[[ -d "$CLOUD_DIR" ]] || { echo "Missing $CLOUD_DIR"; exit 1; }

stop_3001() {
  fuser -k 3001/tcp 2>/dev/null || true
  pkill -f 'next-server' 2>/dev/null || true
  pkill -f 'next start' 2>/dev/null || true
  if command -v lsof >/dev/null; then
    lsof -ti :3001 | xargs -r kill -9 2>/dev/null || true
  fi
  sleep 2
}

echo "==> Stop :3001"
stop_3001

if ss -tlnp 2>/dev/null | grep -q ':3001 '; then
  echo "WARN: port 3001 still busy — retry kill"
  stop_3001
fi

if ss -tlnp 2>/dev/null | grep -q ':3001 '; then
  echo "ERROR: port 3001 still in use:"
  ss -tlnp | grep 3001 || true
  exit 1
fi

cd "$CLOUD_DIR"
cat > .env.production.local <<'EOF'
NEXT_PUBLIC_LYNX_AUTH_URL=/auth
NEXT_PUBLIC_LYNX_API_BASE=/lynx
NEXT_PUBLIC_LYNX_HUB_URL=https://lynx-hub.ru
NEXT_PUBLIC_LYNX_CABINET_URL=/cabinet
EOF

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "==> Build"
  npm ci
  rm -rf .next
  npm run build
else
  echo "==> Skip build (SKIP_BUILD=1)"
  [[ -d .next ]] || { echo "No .next — run without SKIP_BUILD"; exit 1; }
fi

echo "==> Start"
export NODE_ENV=production
nohup npm run start -- -H 0.0.0.0 -p 3001 >>/var/log/lynx-cloud.log 2>&1 &
sleep 3

if ! curl -fsS http://127.0.0.1:3001/ >/dev/null 2>&1; then
  echo "FAIL: Lynx Cloud not responding"
  tail -25 /var/log/lynx-cloud.log 2>/dev/null || true
  exit 1
fi

HTML=$(curl -fsS http://127.0.0.1:3001/)
if echo "$HTML" | grep -qiE 'medical|аккредитац|CRM аккредитации|Вход в CRM'; then
  echo "ERROR: port 3001 serves medical-accreditation, not Lynx Cloud"
  echo "  Process:"
  ss -tlnp 2>/dev/null | grep ':3001 ' || true
  exit 1
fi
if echo "$HTML" | grep -q 'cloud-light'; then
  echo "OK Lynx Cloud :3001 (cloud-light in HTML)"
elif echo "$HTML" | grep -q 'Lynx Cloud'; then
  echo "OK Lynx Cloud :3001 (Lynx Cloud in HTML)"
elif echo "$HTML" | grep -q "background:#ffffff"; then
  echo "OK Lynx Cloud :3001 (inline white body)"
else
  echo "WARN: Lynx Cloud up but theme markers missing — old build?"
  echo "$HTML" | head -c 400
  exit 1
fi

CACHE=$(curl -sI http://127.0.0.1:3001/ | grep -i '^cache-control:' || true)
echo "    $CACHE"
