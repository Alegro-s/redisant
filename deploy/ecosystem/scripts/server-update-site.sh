#!/usr/bin/env bash
# Обновление на VPS: git pull + полный deploy (без docker pull — обход rate limit).
# Запуск на сервере: sudo bash deploy/ecosystem/scripts/server-update-site.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash $0"; exit 1; }

echo "==> Git pull"
if [[ -d "$PO_ROOT/.git" ]]; then
  git -C "$PO_ROOT" fetch origin
  git -C "$PO_ROOT" checkout -f main
  git pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
  echo "    HEAD: $(git -C "$PO_ROOT" rev-parse --short HEAD) $(git -C "$PO_ROOT" log -1 --format=%s)"
fi

if [[ -f "$SMTP_FILE" ]]; then
  python3 - <<PY
import re
p = "$SMTP_FILE"
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(re.sub(r"\$(?!\$)", "$$", t))
PY
fi

export GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redisant}"
export SKIP_SMTP_CHECK="${SKIP_SMTP_CHECK:-1}"
chmod +x "$ECO/scripts/"*.sh
"$ECO/scripts/server-02-clone-github-redik.sh"

echo ""
echo "==> Desktop MSI (/downloads/ mirror)"
DL_DIR=/srv/waypointmetric/downloads
DESKTOP_MSI=Waypoint_0.1.0_x64_en-US.msi
DESKTOP_S3="https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/project's/waypointdesktop/${DESKTOP_MSI}"
mkdir -p "$DL_DIR"
if command -v curl >/dev/null; then
  if curl -fsSL "$DESKTOP_S3" -o "$DL_DIR/$DESKTOP_MSI"; then
    echo "  OK https://metrika-waypoint.ru/downloads/$DESKTOP_MSI"
  else
    echo "  WARN: не удалось скачать MSI с S3 (кнопки на сайте всё равно ведут на S3)"
  fi
fi

echo ""
echo "==> Health"
ok=0
curl -fsS http://127.0.0.1:8090/health >/dev/null && { echo "  auth-api OK"; ok=$((ok+1)); } || echo "  auth-api FAIL"
curl -fsS http://127.0.0.1:8080/health >/dev/null && { echo "  waypoint-api OK"; ok=$((ok+1)); } || echo "  waypoint-api FAIL"
curl -fsS http://127.0.0.1:8082/health >/dev/null && { echo "  lynx-api OK"; ok=$((ok+1)); } || echo "  lynx-api FAIL"
curl -fsS http://127.0.0.1:3001/ >/dev/null && { echo "  lynx-cloud :3001 OK"; ok=$((ok+1)); } || {
  echo "  lynx-cloud FAIL — последние строки лога:"
  tail -20 /var/log/lynx-cloud.log 2>/dev/null || true
}

echo ""
echo "==> Favicons (файлы в dist)"
for f in /srv/waypointclub/web/favicon-club.svg /srv/waypointmetric/dist/favicon-metric.svg /srv/lynx-hub/dist/favicon.svg; do
  [[ -f "$f" ]] && echo "  OK $f" || echo "  MISSING $f"
done

if ! ss -tlnp 2>/dev/null | grep -q ':443 '; then
  echo ""
  echo "WARN: порт 443 не слушается — HTTPS отключён. Восстановление:"
  echo "  sudo SSL_CERT_DIR=/etc/letsencrypt/live/waypointclub.ru bash $ECO/scripts/server-fix-nginx-ssl.sh"
fi

echo ""
echo "Готово. Проверка снаружи:"
echo "  https://waypointclub.ru/roza"
echo "  https://lynx-hub.ru/"
echo "  https://lynx-cloud.ru/"
