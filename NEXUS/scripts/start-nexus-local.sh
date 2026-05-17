
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v docker &>/dev/null; then
  echo "[NEXUS] Установите Docker и Docker Compose plugin."
  exit 1
fi

if [ -z "${JWT_SECRET:-}" ] || [ "${#JWT_SECRET}" -lt 32 ]; then
  export JWT_SECRET="$(openssl rand -base64 48)"
  echo "[NEXUS] JWT_SECRET сгенерирован на эту сессию."
fi

export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-http://127.0.0.1:8080,http://127.0.0.1:5173,http://localhost:8080,http://localhost:5173}"
export ADMIN_OPEN_REGISTRATION="${ADMIN_OPEN_REGISTRATION:-1}"

echo "[NEXUS] Каталог: $ROOT"
docker compose up -d --build

sleep 2
curl -sS http://127.0.0.1:8080/health || echo "[NEXUS] Проверьте логи: docker compose logs -f api"

if [ "${WITH_ADMIN:-0}" = "1" ]; then
  cd "$ROOT/admin-panel"
  if [ ! -d node_modules ]; then npm ci; fi
  npm run dev
else
  echo ""
  echo "API: http://127.0.0.1:8080  |  Стоп: docker compose down"
  echo "Админка (второй терминал): cd admin-panel && npm ci && npm run dev"
  echo "Flutter: cd client && flutter pub get && flutter run"
fi
