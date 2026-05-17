set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"

if [[ "${PULL_FIRST:-0}" == "1" ]]; then
  echo "[lynx-front] git pull..."
  bash "$STACK/git-pull-all.sh"
fi

export RELOAD_NGINX="${RELOAD_NGINX:-1}"
bash "$NEXUS_ROOT/scripts/lynx-vps-all-up.sh"

echo "[lynx-front] Готово."
echo "  Для почты алертов Waypoint: в server/.env задайте WAYPOINT_ALERT_EMAIL_TO и рабочий OTP_WEBHOOK_URL (send-otp.php)."
