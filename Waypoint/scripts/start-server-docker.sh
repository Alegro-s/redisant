set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -z "${JWT_SECRET:-}" ] || [ "${#JWT_SECRET}" -lt 32 ]; then
  export JWT_SECRET="$(openssl rand -base64 48)"
  echo "[NEXUS] JWT_SECRET сгенерирован для этой сессии."
fi

export CORS_ALLOWED_ORIGINS="${CORS_ALLOWED_ORIGINS:-http://127.0.0.1:8080,http://127.0.0.1:5173,http://localhost:8080,http://localhost:5173}"

echo "[NEXUS] Каталог: $ROOT"
docker compose up -d --build

echo ""
echo "[NEXUS] API: http://127.0.0.1:8080/health"
echo "Логи: docker compose logs -f api"
echo "Стоп: docker compose down"
