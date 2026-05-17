set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
BR="${LYNX_GIT_BRANCH:-main}"

cd "$NEXUS_ROOT"
[[ -d .git ]] || { echo "Нет .git в $NEXUS_ROOT" >&2; exit 1; }

echo "[sync] fetch origin..."
git fetch origin

echo "[sync] checkout origin/$BR — compose + server-stack (сброс локальных правок на VPS)"
git checkout "origin/$BR" -- \
  docker-compose.yml \
  docker-compose.full-stack.yml \
  docker-compose.cloud-db.yml \
  scripts/server-stack/ \
  2>/dev/null || true

echo "[sync] git pull --ff-only"
git pull --ff-only

echo "[sync] Готово. Проверка: git status"
