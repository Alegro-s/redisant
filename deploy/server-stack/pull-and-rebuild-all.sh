set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a

WAYPOINT_ROOT="${WAYPOINT_ROOT:-${NEXUS_ROOT:-$HOME/Waypoint}}"
LYNX_ROOT="${LYNX_ROOT:-$HOME/Lynx}"

echo "[all] === git pull (Waypoint, Lynx, TSPUT) ==="
bash "$STACK/git-pull-all.sh"

echo "[all] === Lynx deploy (API из Waypoint, фронты Lynx + web) ==="
export SKIP_GIT_PULL=1
export WAYPOINT_ROOT
export RELOAD_NGINX="${RELOAD_NGINX:-1}"
bash "$LYNX_ROOT/scripts/lynx-server-deploy.sh"

if [[ "${WITH_TSPUT_DOCKER:-0}" == "1" ]]; then
  echo "[all] === TSPUT Docker (:8081) ==="
  bash "$STACK/tsput-docker-up.sh"
fi

echo ""
echo "[all] Готово."
echo "  Waypoint API: curl -fsS http://127.0.0.1:8080/health"
