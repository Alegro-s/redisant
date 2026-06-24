#!/usr/bin/env bash
# Lynx Hub: git sync, build, deploy static (preserves /downloads/).
# На VPS: sudo bash deploy/ecosystem/scripts/server-deploy-lynx-hub.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"
HUB_DIR="$PO_ROOT/Lynx/hub"
STATIC_DIR="/srv/lynx-hub/dist"
DOWNLOADS_DIR="$STATIC_DIR/downloads"

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash $0"; exit 1; }
[[ -d "$HUB_DIR" ]] || { echo "Missing $HUB_DIR"; exit 1; }

mkdir -p "$STATIC_DIR" "$DOWNLOADS_DIR"

echo "==> Git sync"
bash "$ECO/scripts/server-git-sync.sh"

echo "==> Hub env (.env.production.local)"
bash "$ECO/scripts/write-hub-env-production.sh" "$HUB_DIR/.env.production.local"

echo "==> Build Lynx Hub"
cd "$HUB_DIR"
npm ci
npm run build

echo "==> Deploy static (keep $DOWNLOADS_DIR)"
rsync -a --delete --exclude 'downloads/' dist/ "$STATIC_DIR/"

if [[ -d dist/dist/downloads ]]; then
  echo "==> Sync download manifests"
  mkdir -p "$DOWNLOADS_DIR"
  cp -f dist/dist/downloads/*.json "$DOWNLOADS_DIR/" 2>/dev/null || true
fi

if [[ ! -f "$STATIC_DIR/engine-web/index.html" ]]; then
  echo "WARN: engine-web missing — run Lynx/scripts/build-lynx-engine-web.ps1 on PC and push"
fi

echo "==> Health"
curl -fsS http://127.0.0.1:8082/health >/dev/null && echo "  lynx-api OK" || echo "  lynx-api FAIL"
curl -fsS http://127.0.0.1:8090/health >/dev/null && echo "  auth-api OK" || echo "  auth-api FAIL"

if nginx -t 2>/dev/null; then
  systemctl reload nginx 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo "Lynx Hub deployed: $(git -C "$PO_ROOT" rev-parse --short HEAD)"
echo "  https://lynx-hub.ru/"
echo "  https://lynx-hub.ru/engine-web/"
echo "  https://lynx-hub.ru/download"
echo "  https://lynx-hub.ru/downloads/"
if [[ -f "$DOWNLOADS_DIR/engine-manifest.json" ]]; then
  echo "  https://lynx-hub.ru/downloads/engine-manifest.json"
fi
echo "=============================================="
