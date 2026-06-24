#!/usr/bin/env bash
# Полный деплой админ-панелей Lynx (Hub account + Cloud cabinet + API + S3).
# На VPS: sudo bash deploy/ecosystem/scripts/server-deploy-lynx-admin.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }
[[ -d "$PO_ROOT/.git" ]] || { echo "Missing $PO_ROOT"; exit 1; }
[[ -f "$SMTP_FILE" ]] || { echo "Missing $SMTP_FILE — copy from deploy/ecosystem/smtp.env.example"; exit 1; }

echo "==> Git pull"
git -C "$PO_ROOT" fetch origin
git -C "$PO_ROOT" checkout -f main
git -C "$PO_ROOT" pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
echo "    HEAD: $(git -C "$PO_ROOT" rev-parse --short HEAD) $(git -C "$PO_ROOT" log -1 --format=%s)"

chmod +x "$ECO/scripts/"*.sh 2>/dev/null || true

echo "==> Lynx DB migration (analytics + nexus promote)"
bash "$ECO/scripts/server-promote-lynx-ops.sh"

echo "==> Rebuild lynx-api (new endpoints + S3)"
cd "$ECO"
docker compose --env-file "$SMTP_FILE" -f docker-compose.apis.yml build lynx-api
docker compose --env-file "$SMTP_FILE" -f docker-compose.apis.yml up -d lynx-api

echo "==> Wait lynx-api"
for i in $(seq 1 45); do
  if curl -fsS http://127.0.0.1:8082/health >/dev/null 2>&1; then
    echo "    lynx-api OK"
    break
  fi
  sleep 1
  if [[ "$i" -eq 45 ]]; then
    docker logs waypoint-lynx-api --tail 40
    exit 1
  fi
done

echo "==> Build Hub (account + admin)"
if [[ -d "$PO_ROOT/Lynx/hub" ]]; then
  cd "$PO_ROOT/Lynx/hub"
  npm ci
  bash "$ECO/scripts/write-hub-env-production.sh" .env.production.local
  npm run build
  rsync -a --delete dist/ /srv/lynx-hub/dist/
  echo "    Hub -> /srv/lynx-hub/dist"
fi

echo "==> Lynx Cloud (cabinet + admin)"
bash "$ECO/scripts/server-restart-lynx-cloud.sh"

echo "==> nginx reload"
if nginx -t 2>/dev/null; then
  systemctl reload nginx
fi

echo ""
echo "==> Verify routes"
ROUTES=$(grep -c 'cabinet/projects' "$PO_ROOT/Lynx/cloud/.next/server/app-paths-manifest.json" 2>/dev/null || echo 0)
if [[ "$ROUTES" -gt 0 ]]; then
  echo "    OK new cabinet routes in Next build"
else
  echo "    WARN: cabinet/projects not in build — check Lynx/cloud"
fi

curl -fsS -o /dev/null -w "    lynx-cloud /cabinet/dashboard -> %{http_code}\n" http://127.0.0.1:3001/cabinet/dashboard || true
curl -fsS -o /dev/null -w "    lynx-api /health -> %{http_code}\n" http://127.0.0.1:8082/health || true

echo ""
echo "=============================================="
echo "Готово. Проверьте в браузере (Ctrl+F5):"
echo "  https://lynx-hub.ru/sign-in     -> /account или /admin"
echo "  https://lynx-cloud.ru/cabinet/sign-in -> dashboard"
echo "  https://lynx-cloud.ru/admin     (nexus: rozalityai@gmail.com)"
echo ""
echo "S3 keys: добавьте в $SMTP_FILE"
echo "  LYNX_S3_ACCESS_KEY=..."
echo "  LYNX_S3_SECRET_KEY=..."
echo "  затем: sudo bash $ECO/scripts/server-repair-apis.sh"
echo "=============================================="
