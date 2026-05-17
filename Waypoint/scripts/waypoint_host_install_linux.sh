
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запустите от root: sudo bash $0" >&2
  exit 1
fi

INGEST_URL="${WAYPOINT_INGEST_URL:-}"
API_KEY="${WAYPOINT_API_KEY:-}"
if [[ -z "$INGEST_URL" || -z "$API_KEY" ]]; then
  echo "Задайте WAYPOINT_INGEST_URL и WAYPOINT_API_KEY в окружении." >&2
  exit 1
fi

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/waypoint_host_send_metrics.sh"
if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "Не найден $SCRIPT_SRC" >&2
  exit 1
fi

install -m 755 "$SCRIPT_SRC" /usr/local/bin/waypoint_host_send_metrics.sh
umask 077
cat >/etc/waypoint-metrics.env <<EOF
WAYPOINT_INGEST_URL=$INGEST_URL
WAYPOINT_API_KEY=$API_KEY
WAYPOINT_HOST_LABEL=$(hostname -s 2>/dev/null || hostname)
EOF
chmod 600 /etc/waypoint-metrics.env

cat >/etc/systemd/system/waypoint-host-metrics.service <<'UNIT'
[Unit]
Description=Waypoint host metrics -> ingest
After=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/waypoint-metrics.env
ExecStart=/usr/local/bin/waypoint_host_send_metrics.sh
UNIT

cat >/etc/systemd/system/waypoint-host-metrics.timer <<'TIMER'
[Unit]
Description=Run Waypoint host metrics every 2 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now waypoint-host-metrics.timer
echo "Готово. Проверка: systemctl status waypoint-host-metrics.timer"
echo "Логи: journalctl -u waypoint-host-metrics.service -n 20"
