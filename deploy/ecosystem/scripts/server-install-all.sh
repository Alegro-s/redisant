#!/usr/bin/env bash
# =============================================================================
# ONE-SCRIPT INSTALL (paste on VPS as root)
#
#   curl -fsSL ...   OR:
#   nano /root/install.sh   (paste this file)
#   chmod +x /root/install.sh && /root/install.sh
#
# Before run:
#   1) Push code to https://github.com/Alegro-s/redik  (branch main)
#   2) Create /opt/waypoint/smtp.env  (see below) OR set SKIP_SMTP_CHECK=1 for test only
#
# Optional env:
#   GITHUB_REPO=Alegro-s/redik
#   GITHUB_BRANCH=main
#   DEPLOY_ROOT=/opt/waypoint
#   AUTO_YES=1          skip wipe confirmation
# =============================================================================
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redik}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
CLONE_URL="https://github.com/${GITHUB_REPO}.git"
AUTO_YES="${AUTO_YES:-0}"

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

echo "=============================================="
echo " Waypoint / Lynx / Roza — full server install"
echo " Repo: $CLONE_URL ($GITHUB_BRANCH)"
echo "=============================================="

# --- wipe ---
if [[ "$AUTO_YES" != "1" ]]; then
  read -r -p "Delete ALL Docker data and old deploy? Type YES: " confirm
  [[ "$confirm" == "YES" ]] || { echo "Cancelled."; exit 0; }
else
  echo "AUTO_YES=1 — wiping without prompt"
fi

echo "[1/6] Stop and wipe Docker..."
systemctl stop waypoint-auth lynx-cloud nexus 2>/dev/null || true
if command -v docker >/dev/null 2>&1; then
  docker ps -q 2>/dev/null | xargs -r docker stop 2>/dev/null || true
  docker ps -aq 2>/dev/null | xargs -r docker rm -f 2>/dev/null || true
  for dir in "$DEPLOY_ROOT" /root/nexus /root/tsput_profile "$HOME/nexus" "$HOME/tsput_profile"; do
    [[ -f "$dir/docker-compose.yml" ]] && (cd "$dir" && docker compose down -v --remove-orphans 2>/dev/null) || true
  done
  docker system prune -af --volumes 2>/dev/null || true
fi

rm -rf "$HOME/nexus" "$HOME/tsput_profile" "$HOME/lynx_check.sh" "$HOME/lynx_check_output.txt"
rm -rf /opt/waypoint/redik 2>/dev/null || true
mkdir -p "$DEPLOY_ROOT" /srv/waypointclub/web /srv/waypointmetric/dist /srv/lynx-hub/dist /srv/roza/web/dist /var/www/certbot

echo "[2/6] Install system packages..."
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

echo "[3/6] Clone GitHub..."
if [[ -d "$DEPLOY_ROOT/redik/.git" ]]; then
  git -C "$DEPLOY_ROOT/redik" fetch origin
  git -C "$DEPLOY_ROOT/redik" checkout "$GITHUB_BRANCH"
  git -C "$DEPLOY_ROOT/redik" pull --ff-only origin "$GITHUB_BRANCH"
else
  git clone --depth 1 --branch "$GITHUB_BRANCH" "$CLONE_URL" "$DEPLOY_ROOT/redik"
fi

PO_ROOT="$DEPLOY_ROOT/redik"
ECO="$PO_ROOT/deploy/ecosystem"
[[ -d "$ECO" ]] || { echo "ERROR: $ECO missing in repo"; exit 1; }

echo "[4/6] Config smtp.env..."
if [[ ! -f "$DEPLOY_ROOT/smtp.env" ]]; then
  if [[ -f "$ECO/smtp.env.example" ]]; then
    cp "$ECO/smtp.env.example" "$DEPLOY_ROOT/smtp.env"
  fi
fi
if [[ ! -f "$DEPLOY_ROOT/smtp.env" ]]; then
  echo "ERROR: create $DEPLOY_ROOT/smtp.env (JWT_SECRET, POSTGRES_PASSWORD, Yandex SMTP)"
  echo "  nano $DEPLOY_ROOT/smtp.env"
  exit 1
fi
if [[ "${SKIP_SMTP_CHECK:-0}" != "1" ]]; then
  if grep -q "app-password-here\|придумайте\|change-webhook" "$DEPLOY_ROOT/smtp.env" 2>/dev/null; then
    echo "ERROR: edit $DEPLOY_ROOT/smtp.env — replace placeholder passwords"
    exit 1
  fi
fi

echo "[5/6] Docker stacks..."
cd "$ECO"
docker compose -f docker-compose.auth.yml --env-file "$DEPLOY_ROOT/smtp.env" up -d --build
for i in $(seq 1 45); do
  [[ "$(docker inspect --format '{{.State.Health.Status}}' waypoint-db 2>/dev/null || echo x)" == "healthy" ]] && break
  sleep 2
done
docker compose -f docker-compose.apis.yml --env-file "$DEPLOY_ROOT/smtp.env" up -d --build
[[ -f docker-compose.roza.yml ]] && docker compose -f docker-compose.roza.yml up -d --build || true

echo "[6/6] Build sites + nginx..."
if [[ -d "$PO_ROOT/Waypoint/web" ]]; then
  cd "$PO_ROOT/Waypoint/web"
  npm ci
  echo 'VITE_PUBLIC_SITE_MODE=club' > .env.production.local
  npm run build
  rsync -a --delete dist/ /srv/waypointclub/web/
  echo 'VITE_PUBLIC_SITE_MODE=metric' > .env.production.local
  npm run build
  rsync -a --delete dist/ /srv/waypointmetric/dist/
fi
if [[ -d "$PO_ROOT/Lynx/hub" ]]; then
  cd "$PO_ROOT/Lynx/hub" && npm ci && npm run build && rsync -a --delete dist/ /srv/lynx-hub/dist/
fi
if [[ -d "$PO_ROOT/roza/web" ]]; then
  cd "$PO_ROOT/roza/web" && npm ci && npm run build && rsync -a --delete dist/ /srv/roza/web/dist/
fi
if [[ -d "$PO_ROOT/Lynx/cloud" ]]; then
  cd "$PO_ROOT/Lynx/cloud"
  npm ci && npm run build
  pkill -f "next start.*3001" 2>/dev/null || true
  nohup npm run start -- -p 3001 > /var/log/lynx-cloud.log 2>&1 &
fi
if [[ -f "$ECO/nginx/waypoint-ecosystem.conf" ]]; then
  cp "$ECO/nginx/waypoint-ecosystem.conf" /etc/nginx/sites-available/waypoint-ecosystem.conf
  ln -sf /etc/nginx/sites-available/waypoint-ecosystem.conf /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
fi

echo ""
echo "=============================================="
echo " DONE"
echo "=============================================="
echo "  Code:  $PO_ROOT"
echo "  Auth:  curl -sI http://127.0.0.1:8090/health"
echo "  API:   curl -sI http://127.0.0.1:8080/health"
echo ""
echo "  HTTPS (when DNS -> this server):"
echo "  certbot --nginx -d waypointclub.ru -d www.waypointclub.ru \\"
echo "    -d metrika-waypoint.ru -d www.metrika-waypoint.ru \\"
echo "    -d lynx-hub.ru -d www.lynx-hub.ru \\"
echo "    -d lynx-cloud.ru -d www.lynx-cloud.ru"
