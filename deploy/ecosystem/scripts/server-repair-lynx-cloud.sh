#!/usr/bin/env bash
# Fix lynx-cloud.ru when it shows medical-accreditation (wrong process on :3001).
#   sudo bash deploy/ecosystem/scripts/server-repair-lynx-cloud.sh
set -euo pipefail

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"

[[ $EUID -eq 0 ]] || { echo "Run: sudo bash $0"; exit 1; }

bash "$ECO/scripts/server-git-sync.sh"

bad_html() {
  local html="$1"
  echo "$html" | grep -qiE 'medical|аккредитац|CRM аккредитации|Вход в CRM'
}

echo "=============================================="
echo "Lynx Cloud repair (:3001 + nginx)"
echo "=============================================="

echo ""
echo "==> Port :3001"
ss -tlnp 2>/dev/null | grep ':3001 ' || echo "  (nothing listening)"

HTML_3001="$(curl -fsS http://127.0.0.1:3001/ 2>/dev/null || true)"
if [[ -n "$HTML_3001" ]]; then
  title="$(echo "$HTML_3001" | grep -oP '(?<=<title>)[^<]+' | head -1 || true)"
  echo "  direct :3001 title=${title:-?}"
  if bad_html "$HTML_3001"; then
    echo "  *** WRONG APP on :3001 (medical) — will kill and restart Lynx Cloud ***"
  fi
else
  echo "  :3001 not responding"
fi

echo ""
echo "==> nginx → lynx-cloud.ru (local)"
loc="$(curl -sSI -H 'Host: lynx-cloud.ru' http://127.0.0.1/ 2>/dev/null | grep -i '^location:' | head -1 || true)"
code="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: lynx-cloud.ru' http://127.0.0.1/ 2>/dev/null || echo err)"
echo "  HTTP $code ${loc:-}"
if echo "$loc" | grep -qiE 'medical|accreditation'; then
  echo "  *** nginx redirects to medical ***"
fi

echo ""
echo "==> Public HTTPS (from VPS)"
curl -sSI https://lynx-cloud.ru/ 2>/dev/null | head -8 || echo "  curl failed"

echo ""
echo "==> Stop wrong listeners on :3001"
if command -v docker >/dev/null; then
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if docker port "$name" 2>/dev/null | grep -q '3001'; then
      echo "  docker stop $name (was on 3001)"
      docker stop "$name" >/dev/null 2>&1 || true
    fi
  done < <(docker ps --format '{{.Names}}' 2>/dev/null || true)
fi

echo ""
echo "==> Restart Lynx Cloud Next.js"
bash "$ECO/scripts/server-restart-lynx-cloud.sh"

echo ""
echo "==> Reload nginx"
bash "$ECO/scripts/server-fix-nginx-ssl.sh"

echo ""
echo "==> Verify"
HTML_3001="$(curl -fsS http://127.0.0.1:3001/)"
title="$(echo "$HTML_3001" | grep -oP '(?<=<title>)[^<]+' | head -1 || true)"
echo "  :3001 title=$title"
curl -sSI -H 'Host: lynx-cloud.ru' http://127.0.0.1/ 2>/dev/null | head -5 || true
echo ""
echo "Open https://lynx-cloud.ru/ (Ctrl+Shift+R)"
echo "=============================================="
