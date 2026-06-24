#!/usr/bin/env bash
# Write Lynx/hub/.env.production.local from smtp.env (VPS build).
set -euo pipefail

OUT="${1:-Lynx/hub/.env.production.local}"
SMTP_FILE="${SMTP_FILE:-/opt/waypoint/smtp.env}"

HUB_ADMIN_TOKEN=""
if [[ -f "$SMTP_FILE" ]]; then
  HUB_ADMIN_TOKEN="$(grep -E '^LYNX_HUB_ADMIN_TOKEN=' "$SMTP_FILE" | head -1 | cut -d= -f2- | tr -d '\r' || true)"
fi

cat > "$OUT" <<EOF
VITE_LYNX_AUTH_URL=/auth
VITE_LYNX_API_BASE=/lynx
VITE_LYNX_CABINET_URL=https://lynx-cloud.ru/cabinet
VITE_LYNX_CLOUD_URL=https://lynx-cloud.ru
VITE_HUB_ADMIN_TOKEN=${HUB_ADMIN_TOKEN}
EOF

if [[ -n "$HUB_ADMIN_TOKEN" ]]; then
  echo "    VITE_HUB_ADMIN_TOKEN from smtp.env"
else
  echo "    WARN: LYNX_HUB_ADMIN_TOKEN not in smtp.env — Hub publish via JWT nexus only"
fi
