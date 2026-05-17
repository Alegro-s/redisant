set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a
TSPUT_ROOT="${TSPUT_ROOT:-$HOME/tsput_profile}"

pull_repo() {
  local dir="$1"
  [[ -d "$dir/.git" ]] || { echo "[pull] пропуск (не git): $dir"; return 0; }
  echo "[pull] $dir"
  (cd "$dir" && git pull --ff-only)
}

pull_repo "$NEXUS_ROOT"
pull_repo "$TSPUT_ROOT"
echo "[pull] Готово."
