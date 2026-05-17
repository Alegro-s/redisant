set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a
TSPUT_ROOT="${TSPUT_ROOT:-$HOME/tsput_profile}"

cd "$TSPUT_ROOT"
[[ -f docker-compose.yml ]] || { echo "Нет docker-compose.yml в $TSPUT_ROOT" >&2; exit 1; }

if [[ -f docker-compose.bind-local-api.yml ]]; then
  echo "[tsput] compose + bind-local-api (:8081 на localhost)"
  docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml up -d --build
else
  echo "[tsput] только docker-compose.yml (порт 8080 — конфликт с NEXUS!)" >&2
  docker compose up -d --build
fi

for i in $(seq 1 45); do
  port=8081
  [[ -f docker-compose.bind-local-api.yml ]] || port=8080
  if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
    echo "[tsput] OK: GET http://127.0.0.1:${port}/health"
    curl -sS "http://127.0.0.1:${port}/health" && echo ""
    exit 0
  fi
  sleep 2
done
echo "[tsput] health не ответил — логи: docker compose logs -f api" >&2
exit 1
