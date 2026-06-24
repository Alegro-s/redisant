#!/usr/bin/env bash
# Master deploy: Waypoint eco + Lynx Hub/engine-web + TSPUT + Poli + health gates.
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
WITH_TSPUT="${WITH_TSPUT:-1}"
WITH_POLI="${WITH_POLI:-0}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }

echo "==> Legacy cleanup (safe)"
bash "$ECO/scripts/server-legacy-cleanup.sh"

echo "==> Waypoint + Lynx sites"
bash "$ECO/scripts/server-update-site.sh"

echo "==> Ensure APIs + Lynx Cloud"
bash "$ECO/scripts/server-ensure-lynx-services.sh"

if [[ "$WITH_TSPUT" == "1" ]] && [[ -f "$PO_ROOT/tsput_profile/docker-compose.yml" ]]; then
  echo "==> TSPUT profile"
  cd "$PO_ROOT/tsput_profile"
  docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml up -d --build
fi

if [[ "$WITH_POLI" == "1" ]] && [[ -f "$PO_ROOT/NGH/poli/deploy/server-update.sh" ]]; then
  echo "==> Poli medical-accreditation"
  bash "$PO_ROOT/NGH/poli/deploy/server-update.sh"
fi

echo "==> Inventory"
bash "$ECO/scripts/server-inventory.sh" "/tmp/lynx-deploy-inventory.md"

echo "==> Public health gates"
FAIL=0
check() {
  if curl -fsS "$1" >/dev/null 2>&1; then echo "  OK $1"; else echo "  FAIL $1"; FAIL=1; fi
}
check https://lynx-hub.ru/
check https://lynx-cloud.ru/
check https://api.lynx-cloud.ru/engine/manifest
check https://metrika-waypoint.ru/
check https://waypointclub.ru/
check https://medical-accreditation.ru/ || true

if [[ "$FAIL" -ne 0 ]]; then
  echo "Some checks failed — see server-ensure-lynx-services.sh"
  exit 1
fi
echo "All critical checks passed."
