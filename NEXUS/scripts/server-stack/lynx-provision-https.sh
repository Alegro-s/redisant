set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
exec bash "$NEXUS_ROOT/scripts/lynx-vps-provision-public.sh"
