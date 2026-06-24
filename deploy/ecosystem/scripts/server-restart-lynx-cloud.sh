#!/usr/bin/env bash
# Hard restart Lynx Cloud Next.js on :3001 (old next-server often survives pkill).
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
CLOUD_DIR="${CLOUD_DIR:-$PO_ROOT/Lynx/cloud}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }
[[ -d "$CLOUD_DIR" ]] || { echo "Missing $CLOUD_DIR"; exit 1; }

echo "==> Stop :3001"
fuser -k 3001/tcp 2>/dev/null || true
pkill -f 'next-server' 2>/dev/null || true
pkill -f 'next start' 2>/dev/null || true
sleep 2

if ss -tlnp 2>/dev/null | grep -q ':3001 '; then
  echo "WARN: port 3001 still busy"
  ss -tlnp | grep 3001 || true
  exit 1
fi

echo "==> Build"
cd "$CLOUD_DIR"
npm ci
cat > .env.production.local <<'EOF'
NEXT_PUBLIC_LYNX_AUTH_URL=/auth
NEXT_PUBLIC_LYNX_API_BASE=/lynx
NEXT_PUBLIC_LYNX_HUB_URL=https://lynx-hub.ru
NEXT_PUBLIC_LYNX_CABINET_URL=/cabinet
EOF
rm -rf .next
npm run build

echo "==> Start"
export NODE_ENV=production
nohup npm run start -- -H 0.0.0.0 -p 3001 >>/var/log/lynx-cloud.log 2>&1 &
sleep 3

HTML=$(curl -fsS http://127.0.0.1:3001/ 2>/dev/null || true)
if echo "$HTML" | grep -q 'cloud-light'; then
  echo "OK Lynx Cloud :3001 (cloud-light in HTML)"
elif curl -fsS http://127.0.0.1:3001/ >/dev/null 2>&1; then
  echo "WARN: Lynx Cloud up but HTML missing cloud-light — check git pull"
else
  echo "FAIL Lynx Cloud"
  tail -20 /var/log/lynx-cloud.log 2>/dev/null || true
  exit 1
fi
