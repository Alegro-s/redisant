set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a
NEXUS_ROOT="${NEXUS_ROOT:-$(cd "$STACK/../.." && pwd)}"

cd "$NEXUS_ROOT"
[[ -f docker-compose.yml ]] || { echo "Нет docker-compose.yml в $NEXUS_ROOT" >&2; exit 1; }
[[ -f .env ]] || { echo "Создайте .env (см. .env.example) в $NEXUS_ROOT" >&2; exit 1; }

echo "[nexus] docker compose up -d --build"
docker compose up -d --build

for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo "[nexus] OK: GET http://127.0.0.1:8080/health"
    curl -sS http://127.0.0.1:8080/health && echo ""
    exit 0
  fi
  sleep 2
done
echo "[nexus] API не ответил за 2 мин — смотрите: docker compose logs -f api" >&2
exit 1
