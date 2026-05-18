#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"
DOCKER_SECRETS="${DOCKER_SECRETS:-$DEPLOY_ROOT/docker.secrets}"
S3_SECRETS="${S3_SECRETS:-$DEPLOY_ROOT/s3.secrets}"
GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redisant}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.twcstorage.ru}"
S3_BUCKET="${S3_BUCKET:-bc39a46d-ee3d-4707-9e3f-9529afb602da}"
S3_PREFIX="${S3_PREFIX:-lynx/}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-/srv/lynx-downloads}"
WITH_TSPU="${WITH_TSPU:-1}"
RUN_CERTBOT="${RUN_CERTBOT:-0}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash deploy-all.sh"; exit 1; }
cd /tmp
log(){ echo "[deploy] $*"; }

load_secrets() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
  log "Загружен: $f"
}

is_placeholder() {
  [[ "$1" == *"логин"* || "$1" == *"токен"* || "$1" == *"docker_hub"* || -z "${1// }" ]]
}

fix_smtp_dollars() {
  [[ -f "$SMTP_FILE" ]] || return 0
  python3 - "$SMTP_FILE" <<'PY'
import re,sys
p=sys.argv[1]; t=open(p,encoding="utf-8").read()
f=re.sub(r"\$(?!\$)","$$",t)
if f!=t: open(p,"w",encoding="utf-8").write(f); print("smtp.env: $ -> $$")
PY
}

docker_login_if_needed() {
  load_secrets "$DOCKER_SECRETS"
  if [[ -n "${DOCKER_USER:-}" && -n "${DOCKER_PASS:-}" ]] && ! is_placeholder "$DOCKER_USER"; then
    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
    return
  fi
  if docker info 2>/dev/null | grep -qi "username"; then
    log "Docker: уже залогинен"
    return
  fi
  log "Docker Hub: создайте $DOCKER_SECRETS (см. docker.secrets.example)"
  log "Вход через Google: hub.docker.com → Security → Access Token"
  docker login || exit 1
}

docker_pull_images() {
  for img in postgres:16-alpine python:3.12-slim rust:1-bookworm debian:bookworm-slim; do
    log "pull $img"
    docker pull "$img"
  done
}

ensure_repo() {
  mkdir -p "$DEPLOY_ROOT"
  if [[ -d "$PO_ROOT/.git" ]]; then
    git -C "$PO_ROOT" fetch origin
    git -C "$PO_ROOT" checkout -f main
    if ! git -C "$PO_ROOT" pull --ff-only origin main; then
      log "Сброс локальных правок в репозитории → origin/main"
      git -C "$PO_ROOT" reset --hard origin/main
      git -C "$PO_ROOT" clean -fd
    fi
  else
    git clone --depth 1 --branch main "https://github.com/${GITHUB_REPO}.git" "$PO_ROOT"
  fi
  [[ -d "$ECO" ]] || { echo "Нет $ECO"; exit 1; }
}

run_stack() {
  [[ -f "$SMTP_FILE" ]] || {
    echo "Скопируйте smtp.env.example → $SMTP_FILE и заполните" >&2
    exit 1
  }
  fix_smtp_dollars
  export GITHUB_REPO SKIP_SMTP_CHECK="${SKIP_SMTP_CHECK:-1}"
  chmod +x "$ECO/scripts/"*.sh 2>/dev/null || true
  "$ECO/scripts/server-02-clone-github-redik.sh"
}

sync_s3() {
  apt-get update -qq
  apt-get install -y -qq python3-pip || true
  pip3 install --break-system-packages awscli 2>/dev/null || pip3 install awscli 2>/dev/null || apt-get install -y -qq awscli || true
  mkdir -p "$DOWNLOADS_DIR" /srv/lynx-hub/dist/downloads
  load_secrets "$S3_SECRETS"
  local extra=()
  if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    extra+=(--no-sign-request)
    log "S3: без ключей (--no-sign-request)"
  else
    export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ru-1}"
  fi
  aws s3 sync "s3://${S3_BUCKET}/${S3_PREFIX}" "$DOWNLOADS_DIR/" \
    --endpoint-url "$S3_ENDPOINT" "${extra[@]}"
}

setup_hub() {
  local hub="$PO_ROOT/Lynx/hub"
  [[ -d "$hub" ]] || return 0
  local exe apk zip
  exe=$(find "$DOWNLOADS_DIR" -type f \( -iname 'LynxLauncher.exe' -o -iname '*launcher*.exe' \) 2>/dev/null | head -1 || true)
  apk=$(find "$DOWNLOADS_DIR" -type f -iname 'app-release.apk' 2>/dev/null | head -1 || true)
  zip=$(find "$DOWNLOADS_DIR" -type f -iname 'LynxLauncher-win-x64.zip' -o -iname '*.zip' 2>/dev/null | head -1 || true)
  mkdir -p /srv/lynx-hub/dist/downloads
  [[ -n "$exe" ]] && cp -f "$exe" "/srv/lynx-hub/dist/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && cp -f "$apk" "/srv/lynx-hub/dist/downloads/$(basename "$apk")"
  [[ -n "$zip" ]] && cp -f "$zip" "/srv/lynx-hub/dist/downloads/$(basename "$zip")"
  local eu="" au="" zu=""
  [[ -n "$exe" ]] && eu="https://lynx-hub.ru/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && au="https://lynx-hub.ru/downloads/$(basename "$apk")"
  [[ -n "$zip" ]] && zu="https://lynx-hub.ru/downloads/$(basename "$zip")"
  cat > "$hub/.env.production" <<EOF
VITE_LYNX_CLOUD_URL=https://lynx-cloud.ru
VITE_WAYPOINT_METRIC_URL=https://metrika-waypoint.ru
VITE_WAYPOINT_CLUB_URL=https://waypointclub.ru
VITE_ENGINE_MANIFEST_URL=https://api.lynx-cloud.ru/engine/manifest
VITE_LYNX_LAUNCHER_EXE_URL=${eu}
VITE_LYNX_LAUNCHER_APK_URL=${au}
VITE_LYNX_SOURCES_ZIP_URL=${zu}
EOF
  cd "$hub" && npm ci && npm run build
  rsync -a --delete dist/ /srv/lynx-hub/dist/
  [[ -n "$exe" ]] && cp -f "$exe" "/srv/lynx-hub/dist/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && cp -f "$apk" "/srv/lynx-hub/dist/downloads/$(basename "$apk")"
  [[ -n "$zip" ]] && cp -f "$zip" "/srv/lynx-hub/dist/downloads/$(basename "$zip")"
  nginx -t && systemctl reload nginx
}

run_tspu() {
  [[ "$WITH_TSPU" == "1" ]] || return 0
  local t="$PO_ROOT/tsput_profile"
  [[ -f "$t/docker-compose.yml" ]] || { log "ТГПУ: пропуск"; return 0; }
  cd "$t"
  docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml up -d --build \
    || docker compose up -d --build
  sleep 2
  curl -fsS http://127.0.0.1:8081/health && log "ТГПУ OK" || true
}

run_certbot() {
  [[ "$RUN_CERTBOT" == "1" && -n "$CERTBOT_EMAIL" ]] || return 0
  apt-get install -y -qq certbot python3-certbot-nginx
  certbot --nginx --non-interactive --agree-tos --email "$CERTBOT_EMAIL" --no-eff-email \
    -d waypointclub.ru -d www.waypointclub.ru \
    -d metrika-waypoint.ru -d www.metrika-waypoint.ru \
    -d lynx-hub.ru -d www.lynx-hub.ru \
    -d lynx-cloud.ru -d www.lynx-cloud.ru
}

log "=== deploy-all ==="
ensure_repo
docker_login_if_needed
docker_pull_images
run_stack
sync_s3
setup_hub
run_tspu
run_certbot
curl -fsS http://127.0.0.1:8090/health && log "auth OK" || true
curl -fsS http://127.0.0.1:8080/health && log "waypoint OK" || true
curl -fsS http://127.0.0.1:8082/health && log "lynx OK" || true
log "=== готово ==="
