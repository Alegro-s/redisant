set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"

echo "[pull-rebuild] git pull..."
bash "$STACK/git-pull-all.sh"

echo "[pull-rebuild] docker compose up --build (NEXUS)..."
bash "$STACK/nexus-docker-up.sh"

if command -v nginx >/dev/null 2>&1; then
  echo "[pull-rebuild] nginx"
  sudo nginx -t
  sudo systemctl reload nginx
fi

echo "[pull-rebuild] готово. Проверка: curl -sS https://api.lynx-cloud.ru/health"
