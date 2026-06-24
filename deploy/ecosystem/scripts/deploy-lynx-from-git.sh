#!/usr/bin/env bash
# Полный деплой Lynx с VPS после git pull.
# Запуск на сервере: sudo bash deploy/ecosystem/scripts/deploy-lynx-from-git.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash $0"; exit 1; }

echo "==> Git pull"
if [[ -d "$PO_ROOT/.git" ]]; then
  git -C "$PO_ROOT" fetch origin
  git -C "$PO_ROOT" checkout -f main 2>/dev/null || true
  git -C "$PO_ROOT" pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
  echo "    HEAD: $(git -C "$PO_ROOT" rev-parse --short HEAD)"
fi

export SKIP_SMTP_CHECK="${SKIP_SMTP_CHECK:-1}"
chmod +x "$ECO/scripts/"*.sh 2>/dev/null || true

echo "==> Lynx API (arcade + hub content)"
cd "$ECO"
docker compose -f docker-compose.apis.yml build lynx-api
docker compose -f docker-compose.apis.yml up -d lynx-api

echo "==> Ensure Lynx Cloud + API (fix 502)"
bash "$ECO/scripts/server-ensure-lynx-services.sh"

echo "==> Все сайты и API"
bash "$ECO/scripts/server-update-site.sh"

echo ""
echo "==> Health"
curl -fsS http://127.0.0.1:8082/health && echo "  lynx-api OK" || echo "  lynx-api FAIL"
curl -fsS http://127.0.0.1:8090/health && echo "  auth-api OK" || echo "  auth-api FAIL"

echo ""
echo "Готово. Проверьте:"
echo "  https://lynx-hub.ru/"
echo "  https://lynx-hub.ru/lynx/v1/arcade/catalog"
echo "  https://lynx-hub.ru/admin"
