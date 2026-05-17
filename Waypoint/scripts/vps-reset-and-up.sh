
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MODE="${1:-local}"
case "$MODE" in
  local)
    COMPOSE=(docker compose)
    ;;
  cloud)
    COMPOSE=(docker compose -f docker-compose.cloud-db.yml)
    ;;
  *)
    echo "Использование: $0 [local|cloud]"
    exit 1
    ;;
esac

if [[ ! -f ".env" ]] && [[ "$MODE" == "local" ]]; then
  echo "[NEXUS] Нет файла .env в $ROOT — для продакшена скопируйте .env.example и задайте JWT_SECRET и т.д."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  ВНИМАНИЕ: будут остановлены контейнеры этого проекта и удалены тома,"
echo "  перечисленные в compose (данные PostgreSQL и uploads — для режима local)."
if [[ "$MODE" == "cloud" ]]; then
  echo "  Режим cloud: облачная Postgres НЕ трогается — только uploads-том API."
fi
echo "═══════════════════════════════════════════════════════════════════"
read -r -p "Введите yes для продолжения: " ans
if [[ "${ans,,}" != "yes" ]]; then
  echo "Отменено."
  exit 1
fi

echo "[NEXUS] docker compose down -v --remove-orphans ..."
"${COMPOSE[@]}" down -v --remove-orphans

if [[ "$MODE" == "cloud" ]]; then
  echo ""
  echo "[NEXUS] Облачная база: для полного сброса схемы выполните у провайдера, например:"
  echo "  # подставьте URL из .env (USER, HOST, DB):"
  echo "  # psql \"\$DATABASE_URL\" -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"
  echo "  # или создайте новую пустую БД и обновите DATABASE_URL в .env"
  echo ""
fi

echo "[NEXUS] docker compose up -d --build ..."
"${COMPOSE[@]}" up -d --build

echo ""
"${COMPOSE[@]}" ps
echo ""
echo "[NEXUS] Проверка API: curl -sS http://127.0.0.1:8080/health"
curl -sS http://127.0.0.1:8080/health && echo "" || echo "(curl не удался — проверьте порт и логи: ${COMPOSE[*]} logs -f api)"
