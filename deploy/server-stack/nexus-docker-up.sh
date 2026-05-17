set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a
WAYPOINT_ROOT="${WAYPOINT_ROOT:-${NEXUS_ROOT:-$HOME/Waypoint}}"

cd "$WAYPOINT_ROOT"
[[ -f docker-compose.yml ]] || { echo "Нет docker-compose.yml в $WAYPOINT_ROOT" >&2; exit 1; }
[[ -f .env ]] || { echo "Создайте .env (см. .env.example) в $WAYPOINT_ROOT" >&2; exit 1; }

echo "[waypoint] docker compose up -d --build"
docker compose up -d --build

for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo "[waypoint] OK: GET http://127.0.0.1:8080/health"
    curl -sS http://127.0.0.1:8080/health && echo ""
    exit 0
  fi
  sleep 2
done
echo "[waypoint] API не ответил — docker compose logs -f api" >&2
exit 1
