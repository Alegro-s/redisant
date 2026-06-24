#!/usr/bin/env bash
# Diagnose / restore Waypoint + Lynx sites when wrong SPA appears (e.g. medical-accreditation).
# Does NOT delete Poli/medical project dirs — only frees ports 80/443 and rebuilds our static.
#
#   sudo bash deploy/ecosystem/scripts/server-repair-ecosystem-sites.sh --diagnose
#   sudo bash deploy/ecosystem/scripts/server-repair-ecosystem-sites.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
DIAGNOSE_ONLY="${1:-}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0 [--diagnose]"; exit 1; }

if [[ -f "$ECO/scripts/server-git-sync.sh" ]]; then
  bash "$ECO/scripts/server-git-sync.sh"
elif [[ -d "$PO_ROOT/.git" ]]; then
  git -C "$PO_ROOT" fetch origin
  git -C "$PO_ROOT" checkout -f main
  git -C "$PO_ROOT" pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
fi

bad_title() {
  local t="${1:-}"
  [[ -z "$t" ]] && return 1
  echo "$t" | grep -qiE 'medical|аккредитац|CRM аккредитации' && return 0
  return 1
}

read_title() {
  local f="$1"
  [[ -f "$f" ]] || { echo "(missing)"; return; }
  grep -oP '(?<=<title>)[^<]+' "$f" 2>/dev/null | head -1 || echo "(no title)"
}

echo "=============================================="
echo "Waypoint / Lynx site repair"
echo "=============================================="

echo ""
echo "==> Who listens on :80 / :443"
ss -tlnp 2>/dev/null | grep -E ':80 |:443 ' || true

echo ""
echo "==> nginx sites-enabled"
ls -la /etc/nginx/sites-enabled/ 2>/dev/null || true

echo ""
echo "==> Static <title> (expect Waypoint / Lynx, NOT medical CRM)"
declare -A EXPECT=(
  ["/srv/waypointclub/web/index.html"]="Waypoint"
  ["/srv/waypointmetric/dist/index.html"]="Waypoint"
  ["/srv/lynx-hub/dist/index.html"]="Lynx"
)
CONTAMINATED=0
for f in "${!EXPECT[@]}"; do
  title="$(read_title "$f")"
  echo "  $f → $title"
  if bad_title "$title"; then
    echo "    *** WRONG (medical-accreditation?) ***"
    CONTAMINATED=$((CONTAMINATED + 1))
  fi
done

echo ""
echo "==> Lynx Cloud :3001 (proxied — not static /srv)"
ss -tlnp 2>/dev/null | grep ':3001 ' || echo "  (nothing on :3001)"
html3001="$(curl -fsS http://127.0.0.1:3001/ 2>/dev/null || true)"
if [[ -n "$html3001" ]]; then
  t3001="$(echo "$html3001" | grep -oP '(?<=<title>)[^<]+' | head -1 || true)"
  echo "  :3001 title=${t3001:-?}"
  if bad_title "$t3001"; then
    echo "    *** WRONG (medical on :3001 — run server-repair-lynx-cloud.sh) ***"
    CONTAMINATED=$((CONTAMINATED + 1))
  fi
else
  echo "  :3001 not responding"
  CONTAMINATED=$((CONTAMINATED + 1))
fi

echo ""
echo "==> nginx vhost smoke (local, by Host header)"
for host in waypointclub.ru lynx-hub.ru metrika-waypoint.ru lynx-cloud.ru; do
  code="$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $host" http://127.0.0.1/ 2>/dev/null || echo err)"
  snippet="$(curl -sSL -H "Host: $host" http://127.0.0.1/ 2>/dev/null | grep -oP '(?<=<title>)[^<]+' | head -1 || true)"
  loc="$(curl -sSI -H "Host: $host" http://127.0.0.1/ 2>/dev/null | grep -i '^location:' | head -1 || true)"
  echo "  Host $host → HTTP $code title=${snippet:-?} ${loc:-}"
  if bad_title "$snippet"; then
    echo "    *** WRONG vhost response ***"
    CONTAMINATED=$((CONTAMINATED + 1))
  fi
  if echo "$loc" | grep -qiE 'medical|accreditation'; then
    echo "    *** redirects to medical ***"
    CONTAMINATED=$((CONTAMINATED + 1))
  fi
done

echo ""
echo "==> Docker publishing :80 or :443 (not nginx = conflict)"
if command -v docker >/dev/null; then
  docker ps --format 'table {{.Names}}\t{{.Ports}}' 2>/dev/null | grep -E '0\.0\.0\.0:(80|443)->|:80->|:443->' || echo "  (none on public 80/443)"
fi

echo ""
echo "==> Extra nginx configs (not waypoint-ecosystem)"
found_extra=0
for f in /etc/nginx/sites-enabled/*; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"
  [[ "$base" == "waypoint-ecosystem.conf" ]] && continue
  echo "  EXTRA: $f"
  found_extra=1
done
[[ "$found_extra" -eq 0 ]] && echo "  (none)"

if [[ "$DIAGNOSE_ONLY" == "--diagnose" ]]; then
  echo ""
  echo "Diagnose only. To repair: sudo bash $0"
  exit 0
fi

echo ""
echo "==> Repair: disable stray nginx sites (keeps waypoint-ecosystem.conf)"
for f in /etc/nginx/sites-enabled/*; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"
  [[ "$base" == "waypoint-ecosystem.conf" ]] && continue
  echo "  rm $f"
  rm -f "$f"
done

echo ""
echo "==> Repair: stop docker containers bound to public :80/:443"
if command -v docker >/dev/null; then
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    [[ "$name" == "nginx" ]] && continue
    ports="$(docker port "$name" 2>/dev/null || true)"
    if echo "$ports" | grep -qE '0\.0\.0\.0:80|0\.0\.0\.0:443|\[::\]:80|\[::\]:443'; then
      echo "  stopping $name (was on 80/443 — move Poli/medical to another port/domain)"
      docker stop "$name" >/dev/null 2>&1 || true
    fi
  done < <(docker ps --format '{{.Names}}' 2>/dev/null || true)
fi

echo ""
echo "==> Repair: restore nginx from repo template"
if [[ -f "$ECO/scripts/server-fix-nginx-ssl.sh" ]]; then
  bash "$ECO/scripts/server-fix-nginx-ssl.sh"
else
  echo "  missing server-fix-nginx-ssl.sh — skip"
fi

echo ""
echo "==> Repair: rebuild static from git (Waypoint + Lynx Hub + Roza)"
if [[ -d "$PO_ROOT/.git" ]]; then
  git -C "$PO_ROOT" fetch origin
  git -C "$PO_ROOT" checkout -f main
  git -C "$PO_ROOT" pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
fi

if [[ -f "$ECO/scripts/server-deploy-all-sites.sh" ]]; then
  SITES_MODE=build bash "$ECO/scripts/server-deploy-all-sites.sh" || {
    echo "  build mode failed — trying server-update-site (full)"
    bash "$ECO/scripts/server-update-site.sh"
  }
else
  bash "$ECO/scripts/server-update-site.sh"
fi

echo ""
echo "==> Lynx Cloud :3001 (dedicated repair)"
bash "$ECO/scripts/server-repair-lynx-cloud.sh"

echo ""
echo "==> After repair — titles"
for f in /srv/waypointclub/web/index.html /srv/waypointmetric/dist/index.html /srv/lynx-hub/dist/index.html; do
  echo "  $f → $(read_title "$f")"
done

echo ""
echo "=============================================="
echo "Done. Hard-refresh browser (Ctrl+Shift+R)."
echo "  https://waypointclub.ru/"
echo "  https://lynx-hub.ru/"
echo "  https://metrika-waypoint.ru/"
echo "  https://lynx-cloud.ru/"
echo ""
echo "Poli/medical: bind to its own domain/port — not 80/443 on this VPS."
echo "=============================================="
