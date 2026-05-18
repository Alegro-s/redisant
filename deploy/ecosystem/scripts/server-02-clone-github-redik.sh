#!/usr/bin/env bash
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redisant}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
CLONE_URL="${CLONE_URL:-https://github.com/${GITHUB_REPO}.git}"

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

cd /tmp || cd /

echo "==> Install packages (git, docker, nginx, node if missing)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq git curl ca-certificates nginx rsync

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
fi

if ! command -v node >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y -qq nodejs
fi

if ! command -v docker >/dev/null 2>&1; then
  apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
fi

mkdir -p "$DEPLOY_ROOT"
mkdir -p /srv/waypointclub/web /srv/waypointmetric/dist /srv/waypointmetric/downloads /srv/lynx-hub/dist /srv/roza/web/roza
mkdir -p /var/www/certbot

echo "==> Clone or update ${CLONE_URL}"
if [[ -d "$DEPLOY_ROOT/redik/.git" ]]; then
  git -C "$DEPLOY_ROOT/redik" fetch origin
  git -C "$DEPLOY_ROOT/redik" checkout -f "$GITHUB_BRANCH"
  if ! git -C "$DEPLOY_ROOT/redik" pull --ff-only origin "$GITHUB_BRANCH"; then
    echo "==> Local changes block pull; reset to origin/${GITHUB_BRANCH}"
    git -C "$DEPLOY_ROOT/redik" reset --hard "origin/${GITHUB_BRANCH}"
    git -C "$DEPLOY_ROOT/redik" clean -fd
  fi
else
  rm -rf "$DEPLOY_ROOT/redik"
  git clone --depth 1 --branch "$GITHUB_BRANCH" "$CLONE_URL" "$DEPLOY_ROOT/redik"
fi

PO_ROOT="$DEPLOY_ROOT/redik"
ECO="$PO_ROOT/deploy/ecosystem"

if [[ ! -d "$ECO" ]]; then
  echo "ERROR: $ECO not found. Is monorepo structure correct in redik?" >&2
  exit 1
fi

echo "==> smtp.env"
if [[ ! -f "$DEPLOY_ROOT/smtp.env" ]]; then
  if [[ -f "$ECO/smtp.env.example" ]]; then
    cp "$ECO/smtp.env.example" "$DEPLOY_ROOT/smtp.env"
    echo "Created $DEPLOY_ROOT/smtp.env from example — EDIT before docker up!"
    echo "  nano $DEPLOY_ROOT/smtp.env"
    exit 1
  else
    echo "ERROR: missing $DEPLOY_ROOT/smtp.env" >&2
    exit 1
  fi
fi

echo "==> Docker: auth stack (migrations)"
cd "$ECO"
docker compose -f docker-compose.auth.yml --env-file "$DEPLOY_ROOT/smtp.env" up -d --build --pull never

echo "Waiting for Postgres..."
for i in $(seq 1 40); do
  st=$(docker inspect --format '{{.State.Health.Status}}' waypoint-db 2>/dev/null || echo "none")
  if [[ "$st" == "healthy" ]]; then break; fi
  sleep 2
done

docker compose -f docker-compose.apis.yml --env-file "$DEPLOY_ROOT/smtp.env" up -d --build --pull never
docker compose -f docker-compose.roza.yml up -d --build --pull never 2>/dev/null || true

echo "==> Build frontends (paths inside monorepo)"
build_vite() {
  local dir="$1"
  local out="$2"
  local env_mode="${3:-}"
  if [[ ! -f "$dir/package.json" ]]; then
    echo "Skip (no package.json): $dir"
    return
  fi
  cd "$dir"
  npm ci
  if [[ -n "$env_mode" && -f ".env.${env_mode}" ]]; then
    npm run build -- --mode "$env_mode" 2>/dev/null || npm run build
  else
    npm run build
  fi
  rsync -a --delete dist/ "$out/"
}

if [[ -d "$PO_ROOT/Waypoint/web" ]]; then
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
  cat > .env.production.local <<'EOF'
VITE_API_URL=/api
VITE_AUTH_URL=/auth
VITE_PUBLIC_SITE_MODE=metric
VITE_FAVICON=/favicon-metric.svg
EOF
  npm run build
  rsync -a --delete dist/ /srv/waypointmetric/dist/
  if [[ -d "$PO_ROOT/releases/waypoint-desktop" ]]; then
    mkdir -p /srv/waypointmetric/downloads
    cp -f "$PO_ROOT/releases/waypoint-desktop/"*.msi /srv/waypointmetric/downloads/ 2>/dev/null || true
    cp -f "$PO_ROOT/releases/waypoint-desktop/"*.exe /srv/waypointmetric/downloads/ 2>/dev/null || true
  fi
  if [[ -d "$PO_ROOT/Waypoint/web/public/downloads" ]]; then
    rsync -a "$PO_ROOT/Waypoint/web/public/downloads/" /srv/waypointmetric/downloads/
  fi
fi

build_vite "$PO_ROOT/Lynx/hub" /srv/lynx-hub/dist

if [[ -d "$PO_ROOT/roza/web" ]]; then
  echo "==> Roza web (/roza/)"
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
fi

echo "==> Lynx Cloud (Next.js)"
if [[ -d "$PO_ROOT/Lynx/cloud" ]]; then
  cd "$PO_ROOT/Lynx/cloud"
  npm ci
  npm run build
  pkill -f "next start.*3001" 2>/dev/null || true
  nohup npm run start -- -p 3001 > /var/log/lynx-cloud.log 2>&1 &
fi

echo "==> nginx"
if [[ -f "$ECO/nginx/waypoint-ecosystem.conf" ]]; then
  cp "$ECO/nginx/waypoint-ecosystem.conf" /etc/nginx/sites-available/waypoint-ecosystem.conf
  ln -sf /etc/nginx/sites-available/waypoint-ecosystem.conf /etc/nginx/sites-enabled/waypoint-ecosystem.conf
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
fi

echo ""
echo "==> Done"
echo "  Repo:    $PO_ROOT"
echo "  Auth:    curl -sI http://127.0.0.1:8090/health"
echo "  Metric:  curl -sI http://127.0.0.1:8080/health"
echo ""
echo "HTTPS (after DNS points to this server):"
echo "  certbot --nginx -d waypointclub.ru -d www.waypointclub.ru \\"
echo "    -d metrika-waypoint.ru -d www.metrika-waypoint.ru \\"
echo "    -d lynx-hub.ru -d www.lynx-hub.ru \\"
echo "    -d lynx-cloud.ru -d www.lynx-cloud.ru"
