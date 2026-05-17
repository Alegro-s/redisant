set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

NEXUS_DIR="${NEXUS_DIR:-/root/NEXUS}"
BRANCH="${BRANCH:-main}"
USE_CLOUD_DB="${USE_CLOUD_DB:-0}"
SITE_ROOT_DIR="${SITE_ROOT_DIR:-/var/www/metrika-waypoint}"
ENABLE_NGINX="${ENABLE_NGINX:-1}"
SKIP_ADMIN_BUILD="${SKIP_ADMIN_BUILD:-0}"
RESET_TO_ORIGIN="${RESET_TO_ORIGIN:-1}"
SETUP_REAL_EMAIL="${SETUP_REAL_EMAIL:-0}"

[[ -d "$NEXUS_DIR" ]] || die "NEXUS_DIR not found: $NEXUS_DIR"
cd "$NEXUS_DIR"

[[ -d .git ]] || die "$NEXUS_DIR is not a git repo"

echo "==> [1/8] Git update (branch=$BRANCH) in $NEXUS_DIR"
git fetch origin --prune
git checkout "$BRANCH"

if [[ "$RESET_TO_ORIGIN" == "1" ]]; then
  git reset --hard "origin/$BRANCH"
  git clean -fd -e ".env" -e "*.bak" || true
fi

git pull --ff-only origin "$BRANCH" || true

COMPOSE=(docker compose)
if [[ "$USE_CLOUD_DB" == "1" ]]; then
  COMPOSE=(docker compose -f docker-compose.cloud-db.yml)
fi

echo "==> [2/8] docker compose up -d --build"
if [[ -f ".env" ]]; then
  echo "[NEXUS] Using existing .env"
else
  echo "[NEXUS] WARNING: .env not found in $NEXUS_DIR (API may fail)."
fi

"${COMPOSE[@]}" up -d --build
"${COMPOSE[@]}" ps

echo "==> [3/8] Wait API health"
for i in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:8080/health" >/dev/null 2>&1; then
    echo "API OK"
    break
  fi
  sleep 2
  if [[ "$i" == "60" ]]; then
    echo "=== docker logs (api last 120 lines) ==="
    "${COMPOSE[@]}" logs --tail=120 api || true
    die "API didn't become ready"
  fi
done

echo "==> [4/8] (optional) setup real email webhook"
if [[ "$SETUP_REAL_EMAIL" == "1" ]]; then
  if [[ -f "scripts/vps-setup-real-email.sh" ]]; then
    chmod +x scripts/vps-setup-real-email.sh
    sudo bash scripts/vps-setup-real-email.sh
  else
    echo "No scripts/vps-setup-real-email.sh in repo, skipping."
  fi
fi

echo "==> [5/8] Build admin-panel + rsync dist (unless skipped)"
if [[ "$SKIP_ADMIN_BUILD" == "0" && -d "admin-panel" ]]; then
  docker run --rm -u "$(id -u):$(id -g)" \
    -v "$NEXUS_DIR/admin-panel:/app" \
    -w /app \
    node:20-bookworm-slim \
    bash -lc "npm ci && npm run build"

  sudo mkdir -p "$SITE_ROOT_DIR"
  sudo rsync -a --delete "$NEXUS_DIR/admin-panel/dist/" "$SITE_ROOT_DIR/"
fi

if [[ "$ENABLE_NGINX" == "1" ]]; then
  echo "==> [6/8] Nginx test + reload (if nginx is available)"
  if command -v nginx >/dev/null 2>&1; then
    sudo nginx -t
    sudo systemctl reload nginx || sudo service nginx reload || true
  else
    echo "nginx not found, skipping reload."
  fi
fi

echo "==> [7/8] Smoke checks"
curl -fsS "http://127.0.0.1:8080/ready" >/dev/null 2>&1 || true

http_code="$(curl -sS -o /dev/null -w "%{http_code}" \
  "http://127.0.0.1:8080/me/system-metrics" || true)"
echo "GET /me/system-metrics => HTTP $http_code (expected 401 without JWT)"

echo "==> [8/8] Done"

