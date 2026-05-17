#!/usr/bin/env bash
# Запуск на VPS (Ubuntu 24.04) от root или через sudo.
# Требует: /opt/waypoint/repos.env, /opt/waypoint/smtp.env
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
ENV_FILE="${ENV_FILE:-$DEPLOY_ROOT/repos.env}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Нет $ENV_FILE — скопируйте repos.env.example" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

export GITHUB_TOKEN
BRANCH="${BRANCH:-main}"

echo "==> Остановка старых стеков и очистка legacy"
docker compose -f "$HOME/nexus/docker-compose.yml" down 2>/dev/null || true
docker compose -f "$HOME/tsput_profile/docker-compose.yml" down 2>/dev/null || true
docker stop $(docker ps -q) 2>/dev/null || true

echo "==> Удаление старых каталогов на сервере"
rm -rf "$HOME/nexus" "$HOME/tsput_profile" "$HOME/lynx_check.sh" "$HOME/lynx_check_output.txt"
mkdir -p "$DEPLOY_ROOT/src" "$DEPLOY_ROOT/stacks"
mkdir -p /srv/waypointclub/web /srv/waypointmetric/dist /srv/lynx-hub/dist /srv/roza/web/dist

clone_or_pull() {
  local name="$1"
  local repo="$2"
  local dest="$DEPLOY_ROOT/src/$name"
  local url="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${repo}.git"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" fetch origin
    git -C "$dest" checkout "$BRANCH"
    git -C "$dest" pull --ff-only origin "$BRANCH"
  else
    git clone --depth 1 --branch "$BRANCH" "$url" "$dest"
  fi
}

echo "==> Клонирование репозиториев GitHub"
clone_or_pull auth "$REPO_AUTH"
clone_or_pull apis "$REPO_APIS"
clone_or_pull club-web "$REPO_CLUB_WEB"
clone_or_pull metric-web "$REPO_METRIC_WEB"
clone_or_pull lynx-hub "$REPO_LYNX_HUB"
clone_or_pull lynx-cloud "$REPO_LYNX_CLOUD"
clone_or_pull roza "$REPO_ROZA"
clone_or_pull roza-web "$REPO_ROZA_WEB"

echo "==> Docker: auth + APIs + roza"
cd "$DEPLOY_ROOT/src/auth"
docker compose -f docker-compose.yml --env-file "$SMTP_FILE" up -d --build

cd "$DEPLOY_ROOT/src/apis"
docker compose -f docker-compose.yml --env-file "$ENV_FILE" up -d --build

cd "$DEPLOY_ROOT/src/roza"
docker compose -f docker-compose.yml up -d --build

echo "==> Сборка фронтендов"
build_vite() {
  local dir="$1"
  local out_subpath="${2:-dist}"
  cd "$dir"
  npm ci
  npm run build
  rsync -a --delete "${dir}/${out_subpath}/" "$3"
}

build_vite "$DEPLOY_ROOT/src/club-web" dist /srv/waypointclub/web/
build_vite "$DEPLOY_ROOT/src/metric-web" dist /srv/waypointmetric/dist/
build_vite "$DEPLOY_ROOT/src/lynx-hub" dist /srv/lynx-hub/dist/
build_vite "$DEPLOY_ROOT/src/roza-web" dist /srv/roza/web/dist/

echo "==> Lynx Cloud (Next.js)"
cd "$DEPLOY_ROOT/src/lynx-cloud"
npm ci
npm run build
# systemd unit или pm2 — пример через nohup:
pkill -f "next start.*3001" 2>/dev/null || true
nohup npm run start -- -p 3001 > /var/log/lynx-cloud.log 2>&1 &

echo "==> nginx"
if [[ -f "$DEPLOY_ROOT/nginx/waypoint-ecosystem.conf" ]]; then
  cp "$DEPLOY_ROOT/nginx/waypoint-ecosystem.conf" /etc/nginx/sites-available/waypoint-ecosystem.conf
  ln -sf /etc/nginx/sites-available/waypoint-ecosystem.conf /etc/nginx/sites-enabled/waypoint-ecosystem.conf
  nginx -t && systemctl reload nginx
fi

echo "==> Готово. Проверьте:"
echo "  curl -sI http://127.0.0.1:8090/health || true"
echo "  curl -sI http://waypointclub.ru/ | head -1"
