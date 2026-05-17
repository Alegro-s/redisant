
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f ".env" ]]; then
  echo "[NEXUS] Нет .env в $ROOT — скопируйте: cp .env.example .env && отредактируйте JWT_SECRET и CORS."
  exit 1
fi

echo "[NEXUS] git pull..."
git pull --ff-only

echo "[NEXUS] docker compose up -d --build..."
docker compose up -d --build

echo ""
docker compose ps
echo ""
echo "[NEXUS] Проверка: curl -sS http://127.0.0.1:8080/health"
