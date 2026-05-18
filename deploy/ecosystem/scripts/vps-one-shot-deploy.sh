#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"
SECRETS_FILE="${SECRETS_FILE:-$DEPLOY_ROOT/deploy.secrets}"
GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redisant}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.twcstorage.ru}"
S3_BUCKET="${S3_BUCKET:-bc39a46d-ee3d-4707-9e3f-9529afb602da}"
S3_REGION="${S3_REGION:-ru-1}"
DOWNLOADS_DIR="${DOWNLOADS_DIR:-/srv/lynx-downloads}"
SKIP_SMTP_CHECK="${SKIP_SMTP_CHECK:-1}"
WITH_TSPU="${WITH_TSPU:-1}"
RUN_CERTBOT="${RUN_CERTBOT:-0}"
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Запускайте от root: sudo bash $0" >&2
  exit 1
fi

cd /tmp || cd /

log() { echo "[deploy] $*"; }

fix_smtp_dollars() {
  [[ -f "$SMTP_FILE" ]] || return 0
  python3 - "$SMTP_FILE" << 'PY'
import re, sys
p = sys.argv[1]
t = open(p, encoding="utf-8").read()
fixed = re.sub(r"\$(?!\$)", "$$", t)
if fixed != t:
    open(p, "w", encoding="utf-8").write(fixed)
    print("smtp.env: экранированы символы $ для Docker Compose")
PY
}

docker_hub_login() {
  if [[ -n "${DOCKER_USER:-}" && -n "${DOCKER_PASS:-}" ]]; then
    echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
    return
  fi
  if docker info 2>/dev/null | grep -q "Username:"; then
    log "Docker Hub: уже авторизован"
    return
  fi
  log "Docker Hub: выполните docker login (лимит pull без входа)"
  docker login || {
    echo "Ошибка: нужен docker login. Задайте DOCKER_USER и DOCKER_PASS в $SECRETS_FILE" >&2
    exit 1
  }
}

docker_pull_base_images() {
  log "Загрузка базовых образов..."
  for img in postgres:16-alpine python:3.12-slim rust:1-bookworm debian:bookworm-slim; do
    docker pull "$img" || {
      echo "Не удалось: $img — проверьте docker login и повторите" >&2
      exit 1
    }
  done
}

ensure_repo() {
  mkdir -p "$DEPLOY_ROOT"
  if [[ ! -d "$PO_ROOT/.git" ]]; then
    log "Клонирование $GITHUB_REPO..."
    git clone --depth 1 --branch "$GITHUB_BRANCH" \
      "https://github.com/${GITHUB_REPO}.git" "$PO_ROOT"
  else
    log "Обновление репозитория..."
    git -C "$PO_ROOT" fetch origin
    git -C "$PO_ROOT" checkout "$GITHUB_BRANCH"
    git -C "$PO_ROOT" pull --ff-only origin "$GITHUB_BRANCH" || true
  fi
  [[ -d "$ECO" ]] || { echo "Нет $ECO" >&2; exit 1; }
}

run_stack() {
  [[ -f "$SMTP_FILE" ]] || {
    cp "$ECO/smtp.env.example" "$SMTP_FILE"
    echo "Создан $SMTP_FILE — отредактируйте и запустите снова" >&2
    exit 1
  }
  fix_smtp_dollars
  export GITHUB_REPO GITHUB_BRANCH SKIP_SMTP_CHECK
  chmod +x "$ECO/scripts/"*.sh
  "$ECO/scripts/server-02-clone-github-redik.sh"
}

sync_timeweb_s3() {
  apt-get update -qq
  apt-get install -y -qq awscli curl

  mkdir -p "$DOWNLOADS_DIR" /srv/lynx-hub/dist/downloads

  export AWS_DEFAULT_REGION="$S3_REGION"
  local aws_extra=()
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
  else
    aws_extra+=(--no-sign-request)
    log "S3: публичный бакет (--no-sign-request)"
  fi

  log "Список бакета..."
  aws s3 ls "s3://${S3_BUCKET}/" --endpoint-url "$S3_ENDPOINT" "${aws_extra[@]}"

  log "Синхронизация в $DOWNLOADS_DIR ..."
  aws s3 sync "s3://${S3_BUCKET}/" "$DOWNLOADS_DIR/" \
    --endpoint-url "$S3_ENDPOINT" "${aws_extra[@]}"
}

setup_hub_downloads() {
  local hub="$PO_ROOT/Lynx/hub"
  [[ -d "$hub" ]] || return 0

  local exe apk zip
  exe=$(find "$DOWNLOADS_DIR" -type f \( -iname '*launcher*.exe' -o -iname 'Lynx*.exe' \) 2>/dev/null | head -1 || true)
  apk=$(find "$DOWNLOADS_DIR" -type f -iname '*.apk' 2>/dev/null | head -1 || true)
  zip=$(find "$DOWNLOADS_DIR" -type f -iname '*.zip' 2>/dev/null | head -1 || true)

  mkdir -p /srv/lynx-hub/dist/downloads
  [[ -n "$exe" ]] && cp -f "$exe" "/srv/lynx-hub/dist/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && cp -f "$apk" "/srv/lynx-hub/dist/downloads/$(basename "$apk")"
  [[ -n "$zip" ]] && cp -f "$zip" "/srv/lynx-hub/dist/downloads/$(basename "$zip")"

  local exe_url="" apk_url="" zip_url=""
  [[ -n "$exe" ]] && exe_url="https://lynx-hub.ru/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && apk_url="https://lynx-hub.ru/downloads/$(basename "$apk")"
  [[ -n "$zip" ]] && zip_url="https://lynx-hub.ru/downloads/$(basename "$zip")"

  cat > "$hub/.env.production" << EOF
VITE_LYNX_CLOUD_URL=https://lynx-cloud.ru
VITE_WAYPOINT_METRIC_URL=https://metrika-waypoint.ru
VITE_WAYPOINT_CLUB_URL=https://waypointclub.ru
VITE_ENGINE_MANIFEST_URL=https://api.lynx-cloud.ru/engine/manifest
VITE_LYNX_LAUNCHER_EXE_URL=${exe_url}
VITE_LYNX_LAUNCHER_APK_URL=${apk_url}
VITE_LYNX_SOURCES_ZIP_URL=${zip_url}
EOF

  log "Hub .env.production: EXE=${exe_url:-нет} APK=${apk_url:-нет}"
  cd "$hub"
  npm ci
  npm run build
  rsync -a --delete dist/ /srv/lynx-hub/dist/
  mkdir -p /srv/lynx-hub/dist/downloads
  [[ -n "$exe" ]] && cp -f "$exe" "/srv/lynx-hub/dist/downloads/$(basename "$exe")"
  [[ -n "$apk" ]] && cp -f "$apk" "/srv/lynx-hub/dist/downloads/$(basename "$apk")"
  [[ -n "$zip" ]] && cp -f "$zip" "/srv/lynx-hub/dist/downloads/$(basename "$zip")"

  if [[ -f /etc/nginx/sites-available/waypoint-ecosystem.conf ]]; then
    nginx -t && systemctl reload nginx
  fi
}

run_tspu() {
  [[ "$WITH_TSPU" == "1" ]] || return 0
  local tspu="$PO_ROOT/tsput_profile"
  [[ -f "$tspu/docker-compose.yml" ]] || {
    log "ТГПУ: пропуск (нет tsput_profile/docker-compose.yml)"
    return 0
  }
  cd "$tspu"
  if [[ -f docker-compose.bind-local-api.yml ]]; then
    docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml up -d --build
  else
    docker compose up -d --build
  fi
  sleep 3
  curl -fsS http://127.0.0.1:8081/health && log "ТГПУ API OK" || log "ТГПУ: /health пока не ответил"
}

run_certbot() {
  [[ "$RUN_CERTBOT" == "1" ]] || return 0
  apt-get install -y -qq certbot python3-certbot-nginx
  local email_args=()
  [[ -n "$CERTBOT_EMAIL" ]] && email_args=(--email "$CERTBOT_EMAIL" --agree-tos --no-eff-email)
  certbot --nginx --non-interactive "${email_args[@]}" \
    -d waypointclub.ru -d www.waypointclub.ru \
    -d metrika-waypoint.ru -d www.metrika-waypoint.ru \
    -d lynx-hub.ru -d www.lynx-hub.ru \
    -d lynx-cloud.ru -d www.lynx-cloud.ru
}

health_check() {
  curl -fsS http://127.0.0.1:8090/health >/dev/null && log "auth :8090 OK" || log "auth :8090 — нет ответа"
  curl -fsS http://127.0.0.1:8080/health >/dev/null && log "waypoint :8080 OK" || log "waypoint :8080 — нет ответа"
  curl -fsS http://127.0.0.1:8082/health >/dev/null && log "lynx :8082 OK" || log "lynx :8082 — нет ответа"
}

if [[ -f "$SECRETS_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SECRETS_FILE"
  set +a
  log "Секреты: $SECRETS_FILE"
fi

log "=== Waypoint / Lynx / S3 — полный деплой ==="
ensure_repo
docker_hub_login
docker_pull_base_images
run_stack
sync_timeweb_s3
setup_hub_downloads
run_tspu
run_certbot
health_check

log "=== Готово ==="
log "Код: $PO_ROOT"
log "Сайты: http://lynx-hub.ru  http://metrika-waypoint.ru  http://waypointclub.ru"
log "Загрузки: https://lynx-hub.ru/downloads/"
