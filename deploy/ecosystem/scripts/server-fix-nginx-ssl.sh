#!/usr/bin/env bash
# Быстрое восстановление HTTPS после deploy (если пропал 443).
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "sudo bash $0"; exit 1; }

PO_ROOT="${PO_ROOT:-/opt/waypoint/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SSL_DIR="${SSL_CERT_DIR:-/etc/letsencrypt/live/waypointclub.ru}"

if [[ ! -f "${SSL_DIR}/fullchain.pem" ]]; then
  echo "Нет сертификата в ${SSL_DIR}"
  echo "Выпустите: certbot --nginx -d waypointclub.ru -d www.waypointclub.ru \\"
  echo "  -d metrika-waypoint.ru -d www.metrika-waypoint.ru \\"
  echo "  -d lynx-hub.ru -d www.lynx-hub.ru -d lynx-cloud.ru -d www.lynx-cloud.ru"
  exit 1
fi

mkdir -p /etc/nginx/waypoint-ecosystem
cp -f "$ECO/nginx/includes/"*.conf /etc/nginx/waypoint-ecosystem/
sed -i "s|__SSL_CERT_DIR__|${SSL_DIR}|g" /etc/nginx/waypoint-ecosystem/waypoint-ssl-params.conf
cp -f "$ECO/nginx/waypoint-ecosystem.conf.template" /etc/nginx/sites-available/waypoint-ecosystem.conf
ln -sf /etc/nginx/sites-available/waypoint-ecosystem.conf /etc/nginx/sites-enabled/waypoint-ecosystem.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx
echo "OK: 443 включён. Проверка: ss -tlnp | grep ':443'"
