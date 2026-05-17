set -euo pipefail

NEXUS_DIR="${NEXUS_DIR:-/root/NEXUS}"
cd "$NEXUS_DIR"

USE_CLOUD_DB="${USE_CLOUD_DB:-0}"

COMPOSE=(docker compose)
if [[ "$USE_CLOUD_DB" == "1" ]]; then
  COMPOSE=(docker compose -f docker-compose.cloud-db.yml)
fi

echo "==> docker compose build + up (detached)"
"${COMPOSE[@]}" up -d --build
"${COMPOSE[@]}" ps

echo "==> API health wait"
for i in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
    echo "OK http://127.0.0.1:8080/health"
    exit 0
  fi
  sleep 2
done

echo "API не ответил за ~60 с. Логи api:"
"${COMPOSE[@]}" logs --tail=80 api || true
exit 1
