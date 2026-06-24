#!/usr/bin/env bash
# Write Lynx/hub/.env.production.local from smtp.env (VPS build).
set -euo pipefail

OUT="${1:-Lynx/hub/.env.production.local}"
SMTP_FILE="${SMTP_FILE:-/opt/waypoint/smtp.env}"

HUB_ADMIN_TOKEN=""
if [[ -f "$SMTP_FILE" ]]; then
  HUB_ADMIN_TOKEN="$(grep -E '^LYNX_HUB_ADMIN_TOKEN=' "$SMTP_FILE" | head -1 | cut -d= -f2- | tr -d '\r' || true)"
fi

LAUNCHER_EXE_URL=""
LAUNCHER_APK_URL=""
DL_DIR="/srv/lynx-hub/dist/downloads"
if [[ -d "$DL_DIR" ]]; then
  exe="$(find "$DL_DIR" -maxdepth 1 -type f \( -name '*.exe' -o -name 'Lynx-Launcher*.msi' \) 2>/dev/null | head -1)"
  apk="$(find "$DL_DIR" -maxdepth 1 -type f -name '*.apk' 2>/dev/null | head -1)"
  [[ -n "$exe" ]] && LAUNCHER_EXE_URL="https://lynx-hub.ru/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && LAUNCHER_APK_URL="https://lynx-hub.ru/downloads/$(basename "$apk")"
fi

cat > "$OUT" <<EOF
VITE_LYNX_AUTH_URL=/auth
VITE_LYNX_API_BASE=/lynx
VITE_LYNX_CABINET_URL=https://lynx-cloud.ru/cabinet
VITE_LYNX_CLOUD_URL=https://lynx-cloud.ru
VITE_ENGINE_MANIFEST_URL=https://api.lynx-cloud.ru/engine/manifest
VITE_ENGINE_MANIFEST_CDN_URL=https://lynx-hub.ru/dist/downloads/engine-manifest.json
VITE_LYNX_LAUNCHER_EXE_URL=${LAUNCHER_EXE_URL}
VITE_LYNX_LAUNCHER_APK_URL=${LAUNCHER_APK_URL}
VITE_HUB_ADMIN_TOKEN=${HUB_ADMIN_TOKEN}
EOF

if [[ -n "$HUB_ADMIN_TOKEN" ]]; then
  echo "    VITE_HUB_ADMIN_TOKEN from smtp.env"
else
  echo "    WARN: LYNX_HUB_ADMIN_TOKEN not in smtp.env — Hub publish via JWT nexus only"
fi
