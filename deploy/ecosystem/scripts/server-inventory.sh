#!/usr/bin/env bash
# Inventory report for VPS — ports, docker, nginx, /srv.
set -euo pipefail

REPORT="${1:-/tmp/lynx-server-inventory.md}"
{
  echo "# Lynx VPS inventory"
  echo ""
  echo "Generated: $(date -Is)"
  echo ""
  echo "## Listening ports"
  echo '```'
  ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || true
  echo '```'
  echo ""
  echo "## Docker"
  echo '```'
  docker ps -a 2>/dev/null || echo "docker unavailable"
  echo '```'
  echo ""
  echo "## Nginx sites"
  echo '```'
  ls -la /etc/nginx/sites-enabled 2>/dev/null || true
  echo '```'
  echo ""
  echo "## Static titles"
  for f in \
    /srv/waypointclub/web/index.html \
    /srv/waypointmetric/dist/index.html \
    /srv/lynx-hub/dist/index.html; do
    if [[ -f "$f" ]]; then
      echo "- $f: $(grep -oP '(?<=<title>)[^<]+' "$f" 2>/dev/null | head -1 || echo '?')"
    else
      echo "- MISSING $f"
    fi
  done
  echo ""
  echo '```'
  du -sh /srv/* 2>/dev/null || true
  ls -la /srv 2>/dev/null || true
  echo '```'
  echo ""
  echo "## Health (local)"
  for url in \
    http://127.0.0.1:8090/health \
    http://127.0.0.1:8080/health \
    http://127.0.0.1:8082/health \
    http://127.0.0.1:3001/ \
    http://127.0.0.1:8081/health; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "- OK $url"
    else
      echo "- FAIL $url"
    fi
  done
} | tee "$REPORT"
echo "Report: $REPORT"
