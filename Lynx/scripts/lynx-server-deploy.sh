
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAYPOINT_ROOT="${WAYPOINT_ROOT:-$(cd "$ROOT/../Waypoint" && pwd)}"

SKIP_GIT_PULL="${SKIP_GIT_PULL:-0}"
SKIP_DOCKER="${SKIP_DOCKER:-0}"
SKIP_ADMIN="${SKIP_ADMIN:-0}"
SKIP_HUB="${SKIP_HUB:-0}"
SKIP_CLOUD="${SKIP_CLOUD:-0}"
SKIP_RSYNC="${SKIP_RSYNC:-0}"
LYNX_METRIC_ROOT="${LYNX_METRIC_ROOT:-/srv/waypointmetric/dist}"
LYNX_HUB_ROOT="${LYNX_HUB_ROOT:-/srv/lynx-hub/dist}"
LYNX_CLOUD_SYSTEMD="${LYNX_CLOUD_SYSTEMD:-}"
RELOAD_NGINX="${RELOAD_NGINX:-0}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "[lynx-deploy] Нужна команда: $1" >&2; exit 1; }; }

need git
need docker
need curl
docker compose version >/dev/null 2>&1 || { echo "[lynx-deploy] Нужен Docker Compose v2" >&2; exit 1; }

if [[ "${SKIP_GIT_PULL}" != "1" ]] && [[ -d "$WAYPOINT_ROOT/.git" ]]; then
  echo "[lynx-deploy] git pull Waypoint..."
  (cd "$WAYPOINT_ROOT" && git pull --ff-only)
fi
if [[ "${SKIP_GIT_PULL}" != "1" ]] && [[ -d "$ROOT/.git" ]]; then
  echo "[lynx-deploy] git pull Lynx..."
  (cd "$ROOT" && git pull --ff-only)
fi

if [[ "${SKIP_DOCKER}" != "1" ]]; then
  if [[ ! -f "$WAYPOINT_ROOT/.env" ]]; then
    echo "[lynx-deploy] Нет $WAYPOINT_ROOT/.env — скопируйте .env.example и задайте JWT_SECRET, CORS." >&2
    exit 1
  fi
  echo "[lynx-deploy] docker compose (Waypoint)..."
  (cd "$WAYPOINT_ROOT" && docker compose up -d --build)
  for i in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
      echo "[lynx-deploy] API /health OK"
      break
    fi
    sleep 2
    if [[ "$i" -eq 60 ]]; then
      echo "[lynx-deploy] API не поднялся — логи в $WAYPOINT_ROOT" >&2
      exit 1
    fi
  done
fi

need npm

if [[ "${SKIP_ADMIN}" != "1" ]] && [[ -d "$WAYPOINT_ROOT/web" ]]; then
  echo "[lynx-deploy] Waypoint web: build..."
  (cd "$WAYPOINT_ROOT/web" && npm ci && npm run build)
  if [[ "${SKIP_RSYNC}" != "1" ]]; then
    need sudo
    echo "[lynx-deploy] rsync web/dist → ${LYNX_METRIC_ROOT}"
    sudo mkdir -p "${LYNX_METRIC_ROOT}"
    sudo rsync -a --delete "${WAYPOINT_ROOT}/web/dist/" "${LYNX_METRIC_ROOT}/"
  fi
fi

if [[ "${SKIP_HUB}" != "1" ]] && [[ -d "$ROOT/hub" ]]; then
  echo "[lynx-deploy] Lynx hub: build..."
  (cd "$ROOT/hub" && npm ci && npm run build)
  if [[ "${SKIP_RSYNC}" != "1" ]]; then
    need sudo
    echo "[lynx-deploy] rsync hub/dist → ${LYNX_HUB_ROOT}"
    sudo mkdir -p "${LYNX_HUB_ROOT}"
    sudo rsync -a --delete "${ROOT}/hub/dist/" "${LYNX_HUB_ROOT}/"
  fi
fi

if [[ "${SKIP_CLOUD}" != "1" ]] && [[ -d "$ROOT/cloud" ]]; then
  echo "[lynx-deploy] Lynx cloud: build..."
  (cd "$ROOT/cloud" && npm ci && npm run build)
  if [[ -n "${LYNX_CLOUD_SYSTEMD}" ]]; then
    need sudo
    echo "[lynx-deploy] systemctl restart ${LYNX_CLOUD_SYSTEMD}"
    sudo systemctl restart "${LYNX_CLOUD_SYSTEMD}"
  else
    echo "[lynx-deploy] Перезапустите Next.js (npm run start -p 3001) или задайте LYNX_CLOUD_SYSTEMD."
  fi
fi

if [[ "${RELOAD_NGINX}" == "1" ]]; then
  need sudo
  sudo nginx -t
  sudo systemctl reload nginx
fi

echo ""
echo "[lynx-deploy] Готово."
echo "  Nginx: $WAYPOINT_ROOT/docs/NGINX_PROD_3_SITES_1_APP.conf"
echo "  Домены: $ROOT/docs/LYNX_DOMAINS_AND_DEPLOY.md"
