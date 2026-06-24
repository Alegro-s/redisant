#!/usr/bin/env bash
# VPS: always match origin/main (discard local edits to deploy scripts).
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"

[[ -d "$PO_ROOT/.git" ]] || { echo "Missing $PO_ROOT/.git"; exit 1; }

echo "==> Git sync (origin/main)"
git -C "$PO_ROOT" fetch origin
git -C "$PO_ROOT" checkout -f main
if ! git -C "$PO_ROOT" pull --ff-only origin main 2>/dev/null; then
  echo "    local changes or diverged — reset --hard origin/main"
  git -C "$PO_ROOT" reset --hard origin/main
fi
echo "    HEAD: $(git -C "$PO_ROOT" rev-parse --short HEAD) $(git -C "$PO_ROOT" log -1 --format=%s)"
chmod +x "$ECO/scripts/"*.sh 2>/dev/null || true
