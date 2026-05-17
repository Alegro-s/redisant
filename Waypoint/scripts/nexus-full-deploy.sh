set -euo pipefail

NEXUS_DIR="${NEXUS_DIR:-/opt/nexus}"
GIT_BRANCH="${GIT_BRANCH:-main}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
NEXUS_REPO_URL="${NEXUS_REPO_URL:-https://github.com/Alegro-s/nexus.git}"
SITE_DOMAIN="${SITE_DOMAIN:-https://metrika-waypoint.ru}"
API_DOMAIN="${API_DOMAIN:-https://api.metrika-waypoint.ru}"
SITE_ROOT_DIR="${SITE_ROOT_DIR:-/var/www/metrika-waypoint}"
API_LOCAL_HEALTH_URL="${API_LOCAL_HEALTH_URL:-http://127.0.0.1:8080/health}"

die() { echo "ERROR: $*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Нужна команда: $1 (установи и повтори)"; }

need docker
if ! docker compose version >/dev/null 2>&1; then
  die "Нужен Docker Compose V2 (docker compose)"
fi

need git
need curl
need rsync
need sudo

if [[ ! -d "$NEXUS_DIR/.git" ]]; then
  mkdir -p "$(dirname "$NEXUS_DIR")"
  git clone --branch "$GIT_BRANCH" "$NEXUS_REPO_URL" "$NEXUS_DIR"
fi

cd "$NEXUS_DIR"
echo "==> [1/8] Git update"
git fetch --all --prune
git checkout "$GIT_BRANCH"
git pull --ff-only origin "$GIT_BRANCH"

ORIGINS="${CORS_ALLOWED_ORIGINS:-http://127.0.0.1:8080,http://localhost:8080,http://127.0.0.1:5173,http://localhost:5173}"
if [[ -n "${SITE_DOMAIN:-}" ]]; then
  ORIGINS="${ORIGINS},${SITE_DOMAIN}"
fi

if [[ -z "${JWT_SECRET:-}" ]] && [[ -f ".env" ]]; then
  jwt_from_env="$(sed -n 's/^JWT_SECRET=//p' .env | head -n 1 || true)"
  if [[ -n "${jwt_from_env}" ]]; then
    JWT_SECRET="${jwt_from_env}"
  fi
fi

if [[ -z "${JWT_SECRET:-}" ]] || [[ ${#JWT_SECRET} -lt 32 ]]; then
  die "Задай JWT_SECRET (>=32 символа), например: export JWT_SECRET=\$(openssl rand -base64 48)"
fi

echo "==> [2/8] Write .env"
umask 077
cat > .env <<EOF
JWT_SECRET=${JWT_SECRET}
CORS_ALLOWED_ORIGINS=${ORIGINS}
ADMIN_OPEN_REGISTRATION=${ADMIN_OPEN_REGISTRATION:-0}
EOF

echo "==> [3/8] Build and restart API + Postgres (${COMPOSE_FILE})"
docker compose -f "$COMPOSE_FILE" pull db 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" build --pull api
docker compose -f "$COMPOSE_FILE" up -d

echo "==> [4/8] Wait local API health"
for i in $(seq 1 60); do
  if curl -fsS "$API_LOCAL_HEALTH_URL" >/dev/null 2>&1; then
    echo "API OK"
    break
  fi
  sleep 2
  if [[ "$i" == "60" ]]; then
    docker compose -f "$COMPOSE_FILE" logs --tail=80 api
    die "API не ответил на /health за 2 минуты"
  fi
done

echo "==> [5/8] Build admin-panel (Node in container)"
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "$NEXUS_DIR/admin-panel:/app" \
  -w /app \
  node:20-bookworm-slim \
  bash -lc "npm ci && npm run build"

echo "==> [6/8] Deploy admin-panel dist to ${SITE_ROOT_DIR}"
sudo mkdir -p "$SITE_ROOT_DIR"
sudo rsync -a --delete "$NEXUS_DIR/admin-panel/dist/" "$SITE_ROOT_DIR/"

echo "==> [7/8] Nginx syntax check + reload"
sudo nginx -t
sudo systemctl reload nginx

echo "==> [8/8] Smoke tests"
echo "  - Public API health: ${API_DOMAIN}/health"
curl -fsS "${API_DOMAIN}/health" >/dev/null
echo "    OK"

echo "  - Site root: ${SITE_DOMAIN}/"
curl -fsS "${SITE_DOMAIN}/" >/dev/null
echo "    OK"

echo "  - CORS preflight /api/login"
curl -fsS -X OPTIONS "${API_DOMAIN}/api/login" \
  -H "Origin: ${SITE_DOMAIN}" \
  -H "Access-Control-Request-Method: POST" >/dev/null
echo "    OK"

echo "  - Legacy mobile route check (POST ${SITE_DOMAIN}/login, expect non-5xx)"
legacy_http_code="$(curl -s -o /dev/null -w "%{http_code}" -X POST "${SITE_DOMAIN}/login")"
if [[ "$legacy_http_code" =~ ^5 ]]; then
  die "Legacy /login returned ${legacy_http_code} (server error)"
fi
echo "    HTTP ${legacy_http_code}"

echo ""
echo "DEPLOY DONE"
echo "  Repo:        ${NEXUS_DIR}"
echo "  Site:        ${SITE_DOMAIN}"
echo "  API:         ${API_DOMAIN}"
echo "  Static root: ${SITE_ROOT_DIR}"
docker compose -f "$COMPOSE_FILE" ps
