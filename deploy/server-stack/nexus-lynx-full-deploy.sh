set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a

export RELOAD_NGINX="${RELOAD_NGINX:-1}"
bash "$NEXUS_ROOT/scripts/lynx-vps-all-up.sh"
