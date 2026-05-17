
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

NEW_URL="${1:-}"
if [[ -z "$NEW_URL" ]]; then
  echo "Использование: $0 git@github.com:USER/REPO.git"
  exit 1
fi

git remote set-url origin "$NEW_URL"
echo "[NEXUS] origin -> $NEW_URL"
git remote -v
