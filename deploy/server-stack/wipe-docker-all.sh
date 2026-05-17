set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
NEXUS_ROOT="$(cd "$STACK/../.." && pwd)"
[[ -f "$STACK/paths.env" ]] && set -a && source "$STACK/paths.env" && set +a
TSPUT_ROOT="${TSPUT_ROOT:-$HOME/tsput_profile}"

die() { echo "[wipe] ERROR: $*" >&2; exit 1; }

if [[ "${WIPE_CONFIRM:-}" != "yes" ]]; then
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "  Будут выполнены: docker compose down -v для:"
  echo "    - $NEXUS_ROOT"
  echo "    - $TSPUT_ROOT  (compose + bind-local-api, если есть)"
  echo "  Данные PostgreSQL и uploads NEXUS — удалятся с томами."
  echo "════════════════════════════════════════════════════════════════════"
  read -r -p "Введите yes для продолжения: " ans
  [[ "${ans,,}" == "yes" ]] || { echo "Отменено."; exit 1; }
fi

need() { command -v "$1" >/dev/null 2>&1 || die "нужна команда: $1"; }
need docker
docker compose version >/dev/null 2>&1 || die "нужен Docker Compose v2"

if [[ -f "$NEXUS_ROOT/docker-compose.yml" ]]; then
  echo "[wipe] NEXUS: down -v"
  (cd "$NEXUS_ROOT" && docker compose down -v --remove-orphans)
else
  die "нет $NEXUS_ROOT/docker-compose.yml — проверьте NEXUS_ROOT"
fi

if [[ -d "$TSPUT_ROOT" ]] && [[ -f "$TSPUT_ROOT/docker-compose.yml" ]]; then
  echo "[wipe] tsput_profile: down -v"
  if [[ -f "$TSPUT_ROOT/docker-compose.bind-local-api.yml" ]]; then
    (cd "$TSPUT_ROOT" && docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml down -v --remove-orphans) || true
  fi
  if [[ -f "$TSPUT_ROOT/docker-compose.publish-8080.yml" ]]; then
    (cd "$TSPUT_ROOT" && docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml down -v --remove-orphans) || true
  fi
  (cd "$TSPUT_ROOT" && docker compose down -v --remove-orphans) || true
else
  echo "[wipe] пропуск tsput_profile (нет каталога или docker-compose.yml)"
fi

if [[ "${WIPE_PRUNE:-0}" == "1" ]]; then
  echo "[wipe] docker system prune -f"
  docker system prune -f
fi

echo "[wipe] Готово. Активные контейнеры:"
docker ps -a
