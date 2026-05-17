set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a

echo "[all] === git pull (все репозитории) ==="
bash "$STACK/git-pull-all.sh"

echo "[all] === полная пересборка Lynx (без повторного git pull в NEXUS) ==="
export SKIP_GIT_PULL=1
export RELOAD_NGINX="${RELOAD_NGINX:-1}"
bash "$NEXUS_ROOT/scripts/lynx-vps-all-up.sh"

if [[ "${WITH_TSPUT_DOCKER:-0}" == "1" ]]; then
  echo "[all] === tsput_profile Docker (:8081) ==="
  bash "$STACK/tsput-docker-up.sh"
fi

echo ""
echo "[all] Готово."
echo "  Проверка API: curl -fsS http://127.0.0.1:8080/health"
echo "  Сброс томов Docker + стеки: ./rebuild-and-verify.sh (осторожно: данные в volume)"
