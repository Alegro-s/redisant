set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"

echo "[rebuild] git pull all..."
bash "$STACK/git-pull-all.sh"

echo "[rebuild] wipe docker volumes..."
WIPE_CONFIRM=yes bash "$STACK/wipe-docker-all.sh"

echo "[rebuild] deploy stacks..."
bash "$STACK/deploy-all-stacks.sh"

echo "[rebuild] health checks..."
curl -fsS http://127.0.0.1:8080/health
echo ""
curl -fsS http://127.0.0.1:8081/health
echo ""

if command -v nginx >/dev/null 2>&1; then
  echo "[rebuild] nginx -t"
  sudo nginx -t
  echo "[rebuild] nginx reload"
  sudo systemctl reload nginx
fi

echo "[rebuild] done."
