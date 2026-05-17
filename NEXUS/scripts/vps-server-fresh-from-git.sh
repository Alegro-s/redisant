set -euo pipefail

NEXUS_DIR="${NEXUS_DIR:-$HOME/NEXUS}"
NEXUS_GIT_BRANCH="${NEXUS_GIT_BRANCH:-main}"
MODE="${1:-sync}"
GIT_URL="${2:-}"

backup_env() {
  local dst
  dst="$HOME/nexus.env.backup.$(date +%Y%m%d_%H%M%S)"
  if [[ -f "$NEXUS_DIR/.env" ]]; then
    cp -a "$NEXUS_DIR/.env" "$dst"
    echo "[NEXUS] Сохранён .env → $dst"
  else
    echo "[NEXUS] Нет $NEXUS_DIR/.env — после скрипта создайте из .env.example"
  fi
}

docker_down_volumes() {
  if [[ "${USE_CLOUD_DB:-0}" == "1" ]]; then
    if [[ -f "$NEXUS_DIR/docker-compose.cloud-db.yml" ]]; then
      (cd "$NEXUS_DIR" && docker compose -f docker-compose.cloud-db.yml down -v --remove-orphans) || true
    fi
  else
    if [[ -f "$NEXUS_DIR/docker-compose.yml" ]]; then
      (cd "$NEXUS_DIR" && docker compose down -v --remove-orphans) || true
    fi
  fi
  echo "[NEXUS] Docker: контейнеры остановлены, тома этого compose удалены (-v)."
}

git_sync_hard() {
  cd "$NEXUS_DIR"
  if [[ ! -d .git ]]; then
    echo "[NEXUS] Ошибка: $NEXUS_DIR не похож на git-репозиторий."
    exit 1
  fi
  git fetch origin
  git checkout -B "$NEXUS_GIT_BRANCH" "origin/$NEXUS_GIT_BRANCH"
  git clean -fd
  echo "[NEXUS] Git: совпадает с origin/$NEXUS_GIT_BRANCH, локальные правки сброшены (в т.ч. admin-panel/dist при конфликте pull)."
}

docker_up() {
  cd "$NEXUS_DIR"
  if [[ "${USE_CLOUD_DB:-0}" == "1" ]]; then
    docker compose -f docker-compose.cloud-db.yml up -d --build
    docker compose -f docker-compose.cloud-db.yml ps
  else
    docker compose up -d --build
    docker compose ps
  fi
  echo ""
  curl -sS http://127.0.0.1:8080/health && echo "" || echo "[NEXUS] curl /health не ответил — смотрите docker compose logs -f api"
}

do_reclone() {
  if [[ -z "$GIT_URL" ]]; then
    echo "Укажите URL репозитория:"
    echo "  $0 reclone git@github.com:Alegro-s/nexus.git"
    exit 1
  fi
  local parent name
  parent="$(dirname "$NEXUS_DIR")"
  name="$(basename "$NEXUS_DIR")"
  backup_env
  if [[ -f "$NEXUS_DIR/docker-compose.yml" ]]; then
    (cd "$NEXUS_DIR" && docker compose down -v --remove-orphans) || true
  fi
  if [[ -f "$NEXUS_DIR/docker-compose.cloud-db.yml" ]]; then
    (cd "$NEXUS_DIR" && docker compose -f docker-compose.cloud-db.yml down -v --remove-orphans) || true
  fi
  rm -rf "$NEXUS_DIR"
  git clone --branch "$NEXUS_GIT_BRANCH" "$GIT_URL" "$NEXUS_DIR"
  local latest
  latest="$(ls -t "$HOME"/nexus.env.backup.* 2>/dev/null | head -1 || true)"
  if [[ -n "$latest" ]] && [[ -f "$latest" ]]; then
    cp -a "$latest" "$NEXUS_DIR/.env"
    echo "[NEXUS] Восстановлен .env из $latest"
  fi
  docker_up
}

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  NEXUS_DIR=$NEXUS_DIR  MODE=$MODE  BRANCH=$NEXUS_GIT_BRANCH"
echo "  Будут удалены данные Postgres/uploads в Docker (тома compose)."
if [[ "${USE_CLOUD_DB:-0}" == "1" ]]; then
  echo "  Облачную Postgres скрипт НЕ очищает — только локальные тома API."
fi
echo "══════════════════════════════════════════════════════════════"
read -r -p "Введите yes чтобы продолжить: " ans
if [[ "${ans,,}" != "yes" ]]; then
  echo "Отменено."
  exit 1
fi

if [[ "$MODE" == "reclone" ]]; then
  do_reclone
  exit 0
fi

if [[ ! -d "$NEXUS_DIR" ]]; then
  echo "Каталог не найден: $NEXUS_DIR — используйте: $0 reclone <git-url>"
  exit 1
fi

backup_env
docker_down_volumes
git_sync_hard
docker_up

echo ""
echo "[NEXUS] Готово. Если .env не восстановился автоматически, скопируйте последний файл из ~/nexus.env.backup.*"
