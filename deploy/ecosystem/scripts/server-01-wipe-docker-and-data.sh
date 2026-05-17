#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

read -r -p "This will DELETE all Docker data and old deploy dirs. Type YES: " confirm
if [[ "$confirm" != "YES" ]]; then
  echo "Cancelled."
  exit 0
fi

echo "==> Stop systemd units (if any)"
systemctl stop waypoint-auth 2>/dev/null || true
systemctl stop lynx-cloud 2>/dev/null || true
systemctl stop nexus 2>/dev/null || true

echo "==> Stop all running containers"
if command -v docker >/dev/null 2>&1; then
  docker ps -q | xargs -r docker stop 2>/dev/null || true
  docker compose ls -q 2>/dev/null | while read -r p; do
    docker compose -p "$p" down -v --remove-orphans 2>/dev/null || true
  done
  docker stop $(docker ps -aq) 2>/dev/null || true
  docker rm -f $(docker ps -aq) 2>/dev/null || true

  echo "==> Remove compose projects (common names)"
  for dir in /opt/waypoint /root/nexus /root/tsput_profile "$HOME/nexus" "$HOME/tsput_profile"; do
    if [[ -f "$dir/docker-compose.yml" ]]; then
      (cd "$dir" && docker compose down -v --remove-orphans 2>/dev/null) || true
    fi
  done

  echo "==> Docker system prune (images, volumes, networks)"
  docker system prune -af --volumes

  echo "==> Optional: remove all images again"
  docker rmi -f $(docker images -aq) 2>/dev/null || true
fi

echo "==> Remove legacy directories in HOME"
rm -rf \
  "$HOME/nexus" \
  "$HOME/tsput_profile" \
  "$HOME/lynx_check.sh" \
  "$HOME/lynx_check_output.txt" \
  "$HOME/Waypoint" \
  "$HOME/Lynx"

echo "==> Remove /opt/waypoint and static roots (will re-clone from GitHub)"
rm -rf /opt/waypoint
rm -rf /srv/waypointclub/web \
       /srv/waypointmetric/dist \
       /srv/lynx-hub/dist \
       /srv/roza/web/dist

echo "==> Remove old nginx site (optional backup first)"
if [[ -f /etc/nginx/sites-enabled/waypoint-ecosystem.conf ]]; then
  cp -a /etc/nginx/sites-enabled/waypoint-ecosystem.conf /root/nginx-waypoint-ecosystem.conf.bak.$(date +%Y%m%d) 2>/dev/null || true
  rm -f /etc/nginx/sites-enabled/waypoint-ecosystem.conf
  rm -f /etc/nginx/sites-available/waypoint-ecosystem.conf
  nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
fi

echo "==> Done. Docker disk usage:"
docker system df 2>/dev/null || echo "(docker not installed)"
echo ""
echo "Next: run server-02-clone-github-redik.sh"
