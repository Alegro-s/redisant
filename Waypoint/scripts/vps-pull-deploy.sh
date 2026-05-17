
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BRANCH="${1:-main}"

unset OTP_WEBHOOK_URL 2>/dev/null || true

git fetch origin
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

docker compose build api
docker compose up -d --force-recreate api

if systemctl is-enabled nexus-otp-webhook.service &>/dev/null; then
  systemctl restart nexus-otp-webhook
fi

echo "---"
docker compose exec api printenv OTP_WEBHOOK_URL || true
echo "Готово: API и вебхук перезапущены."
