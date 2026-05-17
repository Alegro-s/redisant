
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_GIT_PULL="${SKIP_GIT_PULL:-0}"
SKIP_ADMIN="${SKIP_ADMIN:-0}"
PUBLIC_ORIGIN="${PUBLIC_ORIGIN:-}"
SITE_ROOT_DIR="${SITE_ROOT_DIR:-}"
RELOAD_NGINX="${RELOAD_NGINX:-1}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[NEXUS] Не найдено: $1 — установите и повторите." >&2
    exit 1
  }
}

require_cmd git
require_cmd docker

if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "[NEXUS] Нужен Docker Compose v2 (docker compose) или docker-compose." >&2
  exit 1
fi

if [[ "${SKIP_GIT_PULL}" != "1" ]] && [[ -d .git ]]; then
  echo "[NEXUS] git pull --ff-only..."
  git pull --ff-only
fi

if [[ ! -f .env ]]; then
  if [[ ! -f .env.example ]]; then
    echo "[NEXUS] Нет .env и .env.example — восстановите файлы из репозитория." >&2
    exit 1
  fi
  echo "[NEXUS] Создаю .env из .env.example..."
  cp .env.example .env
  NEW_SECRET="$(openssl rand -base64 48 | tr -d '\n')"
  if grep -q '^JWT_SECRET=' .env; then
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=${NEW_SECRET}|" .env
  else
    printf '\nJWT_SECRET=%s\n' "${NEW_SECRET}" >> .env
  fi
  if [[ -n "${PUBLIC_ORIGIN}" ]]; then
    ORIG="${PUBLIC_ORIGIN%/}"
    if grep -q '^CORS_ALLOWED_ORIGINS=' .env; then
      sed -i "s|^CORS_ALLOWED_ORIGINS=.*|CORS_ALLOWED_ORIGINS=${ORIG},http://127.0.0.1:8080,http://localhost:8080|" .env
    else
      printf 'CORS_ALLOWED_ORIGINS=%s,http://127.0.0.1:8080,http://localhost:8080\n' "${ORIG}" >> .env
    fi
    echo "[NEXUS] В .env добавлен CORS для PUBLIC_ORIGIN=${ORIG}"
  fi
  echo "[NEXUS] Проверьте .env (CORS, PUBLIC_WEB_BASE_URL, OTP, NEXUS_BOOTSTRAP_ADMIN_EMAIL и т.д.)."
fi

echo "[NEXUS] Docker: подъём db + api..."
"${DC[@]}" up -d --build

echo ""
"${DC[@]}" ps
echo ""

if curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8080/health | grep -q 200; then
  echo "[NEXUS] GET /health — OK"
else
  echo "[NEXUS] Предупреждение: /health не ответил 200 (подождите пару секунд и: curl -sS http://127.0.0.1:8080/health)"
fi

if [[ "${SKIP_ADMIN}" != "1" ]] && [[ -d admin-panel ]]; then
  if command -v npm >/dev/null 2>&1; then
    if [[ ! -f admin-panel/.env ]] && [[ -f admin-panel/.env.example ]]; then
      cp admin-panel/.env.example admin-panel/.env
      echo "[NEXUS] admin-panel/.env создан из примера (VITE_API_URL=/api для прокси на том же домене)."
    fi
    echo "[NEXUS] Сборка admin-panel..."
    (cd admin-panel && npm ci && npm run build)
    echo "[NEXUS] Собрано: $(pwd)/admin-panel/dist"
  else
    echo "[NEXUS] npm не найден — пропуск сборки admin-panel (SKIP_ADMIN=1 или установите Node.js LTS)."
  fi
fi

if [[ -d "${ROOT}/admin-panel/dist" ]]; then
  if [[ -n "${SITE_ROOT_DIR}" ]]; then
    echo "[NEXUS] Публикация фронта: rsync → ${SITE_ROOT_DIR}"
    sudo mkdir -p "${SITE_ROOT_DIR}"
    sudo rsync -a --delete "${ROOT}/admin-panel/dist/" "${SITE_ROOT_DIR}/"
    if [[ "${RELOAD_NGINX}" == "1" ]] && command -v nginx >/dev/null 2>&1; then
      if sudo nginx -t 2>/dev/null; then
        sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null || true
        echo "[NEXUS] nginx reload выполнен"
      else
        echo "[NEXUS] Предупреждение: nginx -t не прошёл — reload пропущен"
      fi
    fi
  else
    echo ""
    echo "[NEXUS] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[NEXUS] На домене старый сайт? Nginx раздаёт другой каталог, не admin-panel/dist в репозитории."
    echo "[NEXUS] Скопируйте сборку и перезагрузите nginx, например:"
    echo "         sudo rsync -a --delete ${ROOT}/admin-panel/dist/ /var/www/ВАШ_САЙТ/"
    echo "         sudo nginx -t && sudo systemctl reload nginx"
    echo "[NEXUS] Или запустите снова с: SITE_ROOT_DIR=/var/www/metrika-waypoint ./scripts/server-run-stack.sh"
    echo "[NEXUS] (путь подставьте как в конфиге server { root ... })"
    echo "[NEXUS] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  fi
fi

echo ""
echo "[NEXUS] Готово."
echo "  API:     http://127.0.0.1:8080  (снаружи — IP:8080 или через reverse proxy)"
echo "  Проверка: curl -sS http://127.0.0.1:8080/health && curl -sS http://127.0.0.1:8080/ready"
echo "  Документация: DEPLOY.md"
