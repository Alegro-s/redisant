#!/usr/bin/env bash
# Stop and remove legacy stacks (nexus, tula-travel) — keep deploy/ecosystem.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }

echo "==> Legacy docker compose down"
for dir in ~/nexus ~/Nexus ~/tula-travel ~/TulaTravelv1.2; do
  if [[ -f "$dir/docker-compose.yml" ]]; then
    echo "  $dir"
    (cd "$dir" && docker compose down -v 2>/dev/null) || true
  fi
done

echo "==> Optional remove legacy dirs (set REMOVE_LEGACY_DIRS=1)"
if [[ "${REMOVE_LEGACY_DIRS:-0}" == "1" ]]; then
  rm -rf ~/nexus ~/Nexus ~/tula-travel ~/TulaTravelv1.2
  echo "  removed"
else
  echo "  skipped (export REMOVE_LEGACY_DIRS=1 to delete)"
fi

echo "Done."
