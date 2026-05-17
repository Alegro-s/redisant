
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WAYPOINT_ROOT="${WAYPOINT_ROOT:-$(cd "$ROOT/../Waypoint" && pwd)}"
cd "$WAYPOINT_ROOT"

if ! command -v docker &>/dev/null; then
  echo "[lynx-local] Нужен Docker + Compose v2."
  exit 1
fi

if [ -z "${JWT_SECRET:-}" ] || [ "${#JWT_SECRET}" -lt 32 ]; then
  export JWT_SECRET="$(openssl rand -base64 48)"
  echo "[lynx-local] JWT_SECRET сгенерирован на эту сессию (для постоянства — положите в Waypoint/.env)."
fi

if [ -z "${CORS_ALLOWED_ORIGINS:-}" ]; then
  export CORS_ALLOWED_ORIGINS="http://127.0.0.1:8080,http://localhost:8080,http://127.0.0.1:5173,http://localhost:5173,http://127.0.0.1:3001,http://localhost:3001,http://127.0.0.1:5175,http://localhost:5175"
fi
export ADMIN_OPEN_REGISTRATION="${ADMIN_OPEN_REGISTRATION:-1}"

echo "[lynx-local] API из Waypoint: $WAYPOINT_ROOT"
echo "[lynx-local] Lynx: $ROOT"
docker compose up -d --build

sleep 2
if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
  echo "[lynx-local] API /health OK"
else
  echo "[lynx-local] Предупреждение: /health не ответил — см. docker compose logs -f api (в $WAYPOINT_ROOT)"
fi

WITH_FRONTENDS="${WITH_FRONTENDS:-0}"
if [ "$WITH_FRONTENDS" != "1" ]; then
  echo ""
  echo "========== Lynx локально (API в Waypoint) =========="
  echo "  API:     http://127.0.0.1:8080  (docker в $WAYPOINT_ROOT)"
  echo "  Стоп:    cd $WAYPOINT_ROOT && docker compose down"
  echo ""
  echo "  Фронты вручную:"
  echo "    cd $WAYPOINT_ROOT/web && npm run dev"
  echo "    cd $ROOT/cloud && npm run dev"
  echo "    cd $ROOT/hub && npm run dev"
  echo ""
  echo "  Все фронты: WITH_FRONTENDS=1 $0"
  echo "===================================================="
  exit 0
fi

if ! command -v npm &>/dev/null; then
  echo "[lynx-local] WITH_FRONTENDS=1 требует npm в PATH."
  exit 1
fi

start_dev() {
  local dir="$1"
  local name="$2"
  if [ ! -f "$dir/package.json" ]; then
    echo "[lynx-local] Пропуск $name: нет $dir/package.json"
    return
  fi
  (
    cd "$dir"
    if [ ! -d node_modules ]; then
      if [ -f package-lock.json ]; then npm ci; else npm install; fi
    fi
    npm run dev
  ) &
  echo "[lynx-local] Запущен в фоне: $name (pid $!)"
}

start_dev "$WAYPOINT_ROOT/web" "Waypoint web"
start_dev "$ROOT/cloud" "Lynx Cloud (next :3001)"
start_dev "$ROOT/hub" "Lynx Hub (vite :5175)"

echo ""
echo "========== Lynx + Waypoint (API + фронты) =========="
echo "  API:        http://127.0.0.1:8080"
echo "  Waypoint:   http://127.0.0.1:5173"
echo "  Lynx Cloud: http://127.0.0.1:3001"
echo "  Lynx Hub:   http://127.0.0.1:5175"
echo "=================================================="

wait
