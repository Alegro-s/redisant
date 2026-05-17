set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"

if [[ "${PULL_FIRST:-0}" == "1" ]]; then
  bash "$STACK/git-pull-all.sh"
fi

bash "$STACK/nexus-docker-up.sh"
bash "$STACK/tsput-docker-up.sh"

echo ""
echo "[deploy-all] Готово."
echo "  Lynx API (NEXUS compose):  http://127.0.0.1:8080/health"
echo "  tsput API:                 http://127.0.0.1:8081/health  (если bind-local-api)"
echo ""
