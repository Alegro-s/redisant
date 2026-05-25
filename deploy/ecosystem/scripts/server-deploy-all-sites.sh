#!/usr/bin/env bash
# Полный деплой сайтов на VPS: git + (сборка из репо ИЛИ бандл S3) + Lynx Cloud + nginx.
#
# Запуск на сервере (root):
#   sudo bash deploy/ecosystem/scripts/server-deploy-all-sites.sh
#
# Режим статики (пока редизайн не в GitHub — используйте s3):
#   sudo SITES_MODE=s3 bash deploy/ecosystem/scripts/server-deploy-all-sites.sh
#
# После push на GitHub — сборка из репозитория:
#   sudo SITES_MODE=build bash deploy/ecosystem/scripts/server-deploy-all-sites.sh
#
# Оба: S3 для club/metric/roza/hub + сборка Lynx Cloud из git:
#   sudo SITES_MODE=s3+build bash deploy/ecosystem/scripts/server-deploy-all-sites.sh
#
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redisant}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
SITES_MODE="${SITES_MODE:-s3}"

S3_ZIP_URL="${S3_ZIP_URL:-https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/deploy/sites/sites-bundle.zip}"
S3_PREFIX_URL="${S3_PREFIX_URL:-https://s3.twcstorage.ru/bc39a46d-ee3d-4707-9e3f-9529afb602da/deploy/sites/latest/}"
S3_SECRETS="${S3_SECRETS:-$DEPLOY_ROOT/s3.secrets}"
BUNDLE_TMP="${BUNDLE_TMP:-/tmp/waypoint-sites-bundle}"

log() { echo "[deploy] $*"; }

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash $0"; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Нет команды: $1"; exit 1; }
}

install_base() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq git curl rsync unzip nginx
  if ! command -v node >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs
  fi
  mkdir -p /srv/waypointclub/web /srv/waypointmetric/dist /srv/waypointmetric/downloads \
    /srv/lynx-hub/dist /srv/roza/web/roza
}

git_update() {
  log "Git: $GITHUB_REPO @ $GITHUB_BRANCH"
  if [[ ! -d "$PO_ROOT/.git" ]]; then
    log "Клонирование в $PO_ROOT"
    git clone --depth 1 --branch "$GITHUB_BRANCH" "https://github.com/${GITHUB_REPO}.git" "$PO_ROOT"
  else
    git -C "$PO_ROOT" fetch origin
    git -C "$PO_ROOT" checkout -f "$GITHUB_BRANCH"
    if ! git -C "$PO_ROOT" merge --ff-only "origin/$GITHUB_BRANCH" 2>/dev/null; then
      log "Сброс локальных правок → origin/$GITHUB_BRANCH"
      git -C "$PO_ROOT" reset --hard "origin/$GITHUB_BRANCH"
      git -C "$PO_ROOT" clean -fd
    fi
  fi
  log "HEAD: $(git -C "$PO_ROOT" rev-parse --short HEAD) — $(git -C "$PO_ROOT" log -1 --format=%s)"
  chmod +x "$ECO/scripts/"*.sh 2>/dev/null || true
}

apply_static_dir() {
  local name="$1"
  local dst="$2"
  if [[ ! -d "$BUNDLE_TMP/$name" ]]; then
    log "SKIP $name (нет в бандле)"
    return 0
  fi
  mkdir -p "$dst"
  rsync -a --delete "$BUNDLE_TMP/$name/" "$dst/"
  log "OK $name → $dst"
}

deploy_from_s3_public_sync() {
  log "Статика: aws s3 sync (публичный бакет, без ключей)"
  need_cmd aws
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ru-1}"
  rm -rf "$BUNDLE_TMP"
  mkdir -p "$BUNDLE_TMP"
  aws s3 sync "s3://bc39a46d-ee3d-4707-9e3f-9529afb602da/deploy/sites/latest/" "$BUNDLE_TMP" \
    --endpoint-url https://s3.twcstorage.ru --no-sign-request
}

deploy_from_s3_zip() {
  log "Статика: ZIP с S3 (без aws)"
  need_cmd curl
  rm -rf "$BUNDLE_TMP"
  mkdir -p "$BUNDLE_TMP"
  local zip="/tmp/waypoint-sites-bundle.zip"
  curl -fSL "$S3_ZIP_URL" -o "$zip"
  if command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$zip" -C "$BUNDLE_TMP"
  elif command -v unzip >/dev/null 2>&1; then
    # unzip может вернуть 1 из‑за backslash в Windows-ZIP — не прерываем деплой
    set +e
    unzip -o "$zip" -d "$BUNDLE_TMP" 2>/dev/null
    local uz=$?
    set -e
    if [[ $uz -ne 0 ]] || [[ ! -d "$BUNDLE_TMP/waypoint-club" ]]; then
      log "ZIP с Windows-путями — fallback на S3 sync"
      deploy_from_s3_public_sync
    fi
  else
    apt-get install -y -qq bsdtar 2>/dev/null || apt-get install -y -qq unzip
    need_cmd bsdtar 2>/dev/null || need_cmd unzip
    bsdtar -xf "$zip" -C "$BUNDLE_TMP" 2>/dev/null || unzip -o "$zip" -d "$BUNDLE_TMP" 2>/dev/null || deploy_from_s3_public_sync
  fi
  ls -la "$BUNDLE_TMP"
  apply_static_dir waypoint-club /srv/waypointclub/web
  apply_static_dir waypoint-metric /srv/waypointmetric/dist
  apply_static_dir lynx-hub /srv/lynx-hub/dist
  apply_static_dir roza /srv/roza/web/roza
  [[ -f /srv/waypointclub/web/favicon-club.svg ]] && \
    cp -f /srv/waypointclub/web/favicon-club.svg /srv/waypointclub/web/favicon.svg 2>/dev/null || true
  [[ -f /srv/waypointmetric/dist/favicon-metric.svg ]] && \
    cp -f /srv/waypointmetric/dist/favicon-metric.svg /srv/waypointmetric/dist/favicon.svg 2>/dev/null || true
}

deploy_from_s3_aws() {
  log "Статика: aws s3 sync"
  if [[ -f "$S3_SECRETS" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$S3_SECRETS"
    set +a
  fi
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    log "Нет ключей в $S3_SECRETS — fallback на ZIP"
    deploy_from_s3_zip
    return
  fi
  if ! command -v aws >/dev/null 2>&1; then
    apt-get install -y -qq awscli 2>/dev/null || true
  fi
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ru-1}"
  rm -rf "$BUNDLE_TMP"
  mkdir -p "$BUNDLE_TMP"
  aws s3 sync "s3://bc39a46d-ee3d-4707-9e3f-9529afb602da/deploy/sites/latest/" "$BUNDLE_TMP" \
    --endpoint-url https://s3.twcstorage.ru
  apply_static_dir waypoint-club /srv/waypointclub/web
  apply_static_dir waypoint-metric /srv/waypointmetric/dist
  apply_static_dir lynx-hub /srv/lynx-hub/dist
  apply_static_dir roza /srv/roza/web/roza
}

build_from_git() {
  log "Статика: npm build из $PO_ROOT"
  need_cmd npm
  if [[ ! -d "$PO_ROOT/Waypoint/web" ]]; then
    echo "ERROR: нет $PO_ROOT/Waypoint/web — сделайте git pull или SITES_MODE=s3" >&2
    exit 1
  fi

  cd "$PO_ROOT/Waypoint/web"
  npm ci
  cat > .env.production.local <<'EOF'
VITE_API_URL=/api
VITE_AUTH_URL=/auth
VITE_PUBLIC_SITE_MODE=club
VITE_FAVICON=/favicon-club.svg
EOF
  npm run build
  rsync -a --delete dist/ /srv/waypointclub/web/
  cp -f /srv/waypointclub/web/favicon-club.svg /srv/waypointclub/web/favicon.svg 2>/dev/null || true

  cat > .env.production.local <<'EOF'
VITE_API_URL=/api
VITE_AUTH_URL=/auth
VITE_PUBLIC_SITE_MODE=metric
VITE_FAVICON=/favicon-metric.svg
EOF
  npm run build
  rsync -a --delete dist/ /srv/waypointmetric/dist/
  cp -f /srv/waypointmetric/dist/favicon-metric.svg /srv/waypointmetric/dist/favicon.svg 2>/dev/null || true

  if [[ -d "$PO_ROOT/Lynx/hub" ]]; then
    cd "$PO_ROOT/Lynx/hub"
    npm ci
    printf '%s\n' 'VITE_LYNX_AUTH_URL=/auth' > .env.production.local
    npm run build
    rsync -a --delete dist/ /srv/lynx-hub/dist/
  fi

  if [[ -d "$PO_ROOT/roza/web" ]]; then
    cd "$PO_ROOT/roza/web"
    npm ci
    cat > .env.production.local <<'EOF'
VITE_BASE=/roza/
VITE_ROZA_API_URL=/roza/api
VITE_AUTH_URL=/auth
EOF
    npm run build
    mkdir -p /srv/roza/web/roza
    rsync -a --delete dist/ /srv/roza/web/roza/
    grep -q '/roza/assets/' /srv/roza/web/roza/index.html || {
      echo "ERROR: Roza VITE_BASE=/roza/ не применился" >&2
      exit 1
    }
  fi
  log "Сборка статики из git завершена"
}

build_lynx_cloud() {
  [[ "$SITES_MODE" == "s3" ]] && return 0
  if [[ ! -d "$PO_ROOT/Lynx/cloud" ]]; then
    log "SKIP Lynx Cloud (нет каталога)"
    return 0
  fi
  log "Lynx Cloud: npm run build + start :3001"
  cd "$PO_ROOT/Lynx/cloud"
  npm ci
  cat > .env.production.local <<'EOF'
NEXT_PUBLIC_LYNX_AUTH_URL=/auth
NEXT_PUBLIC_LYNX_API_BASE=/lynx
NEXT_PUBLIC_LYNX_HUB_URL=https://lynx-hub.ru
NEXT_PUBLIC_LYNX_CABINET_URL=/cabinet
EOF
  npm run build
  pkill -f "next start.*3001" 2>/dev/null || true
  sleep 1
  export NODE_ENV=production
  nohup npm run start -- -H 0.0.0.0 >>/var/log/lynx-cloud.log 2>&1 &
  sleep 3
  if curl -fsS http://127.0.0.1:3001/ >/dev/null; then
    log "Lynx Cloud :3001 OK"
  else
    log "WARN Lynx Cloud — tail /var/log/lynx-cloud.log"
    tail -20 /var/log/lynx-cloud.log 2>/dev/null || true
  fi
}

reload_nginx() {
  if [[ -f "$ECO/scripts/server-02-clone-github-redik.sh" ]]; then
    log "nginx (из server-02)"
    # только блок nginx из server-02 — вызываем весь скрипт дорого; копируем конфиги
    if [[ -d "$ECO/nginx" ]]; then
      mkdir -p /etc/nginx/waypoint-ecosystem
      cp -f "$ECO/nginx/includes/"*.conf /etc/nginx/waypoint-ecosystem/ 2>/dev/null || true
      local dst="/etc/nginx/sites-available/waypoint-ecosystem.conf"
      local ssl_dir="${SSL_CERT_DIR:-/etc/letsencrypt/live/waypointclub.ru}"
      if [[ -f "${ssl_dir}/fullchain.pem" && -f "$ECO/nginx/waypoint-ecosystem.conf.template" ]]; then
        cp -f "$ECO/nginx/waypoint-ecosystem.conf.template" "$dst"
      elif [[ -f "$ECO/nginx/waypoint-ecosystem-http-only.conf" ]]; then
        cp -f "$ECO/nginx/waypoint-ecosystem-http-only.conf" "$dst"
      fi
      sed -i "s|__SSL_CERT_DIR__|${ssl_dir}|g" /etc/nginx/waypoint-ecosystem/waypoint-ssl-params.conf 2>/dev/null || true
      ln -sf "$dst" /etc/nginx/sites-enabled/waypoint-ecosystem.conf
    fi
  fi
  nginx -t
  systemctl reload nginx
  log "nginx reload OK"
}

verify_deploy() {
  log "Проверка файлов"
  for path in \
    /srv/waypointclub/web/index.html \
    /srv/waypointmetric/dist/index.html \
    /srv/lynx-hub/dist/index.html \
    /srv/roza/web/roza/index.html; do
    if [[ -f "$path" ]]; then
      echo "  OK $path ($(stat -c '%y' "$path" 2>/dev/null | cut -d' ' -f1))"
      grep -o '<title>[^<]*</title>' "$path" 2>/dev/null | head -1 || true
    else
      echo "  MISSING $path"
    fi
  done
  if [[ -f /srv/roza/web/roza/index.html ]]; then
    if grep -q 'index-' /srv/roza/web/roza/index.html 2>/dev/null; then
      echo "  Roza asset hash: $(grep -o 'assets/index-[^.]*' /srv/roza/web/roza/index.html | head -1)"
    fi
  fi
}

# --- main ---
echo "=============================================="
echo " Waypoint: git + deploy sites (mode=$SITES_MODE)"
echo "=============================================="

install_base
git_update

case "$SITES_MODE" in
  s3)
    deploy_from_s3_zip
    ;;
  s3aws)
    deploy_from_s3_aws
    ;;
  build)
    build_from_git
    build_lynx_cloud
    ;;
  s3+build | s3-build)
    deploy_from_s3_zip
    build_lynx_cloud
    ;;
  *)
    echo "SITES_MODE=$SITES_MODE неизвестен. Варианты: s3 | build | s3+build | s3aws"
    exit 1
    ;;
esac

reload_nginx
verify_deploy

echo ""
echo "=============================================="
echo " Готово. В браузере: Ctrl+Shift+R (жёсткое обновление)"
echo "  https://waypointclub.ru/"
echo "  https://metrika-waypoint.ru/"
echo "  https://waypointclub.ru/roza/"
echo "  https://waypointclub.ru/roza/security"
echo "  https://lynx-hub.ru/"
echo "  https://lynx-cloud.ru/"
echo ""
echo " Если видите старый Club — на GitHub ещё старый код."
echo " Сейчас актуальная статика в S3 (режим s3). После push:"
echo "   sudo SITES_MODE=build bash $PO_ROOT/deploy/ecosystem/scripts/server-deploy-all-sites.sh"
echo "=============================================="
