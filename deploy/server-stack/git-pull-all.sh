set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a
WAYPOINT_ROOT="${WAYPOINT_ROOT:-${NEXUS_ROOT:-$HOME/Waypoint}}"
LYNX_ROOT="${LYNX_ROOT:-$HOME/Lynx}"
TSPUT_ROOT="${TSPUT_ROOT:-$HOME/tsput_profile}"

pull_repo() {
  local dir="$1"
  [[ -d "$dir/.git" ]] || { echo "[pull] пропуск (не git): $dir"; return 0; }
  echo "[pull] $dir"
  (cd "$dir" && git pull --ff-only)
}

pull_repo "$WAYPOINT_ROOT"
pull_repo "$LYNX_ROOT"
pull_repo "$TSPUT_ROOT"
echo "[pull] Готово."
