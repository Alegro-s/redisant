
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SKIP_GIT_PULL="${SKIP_GIT_PULL:-0}"
SKIP_DOCKER="${SKIP_DOCKER:-0}"
SKIP_ADMIN="${SKIP_ADMIN:-0}"
BUILD_FLUTTER="${BUILD_FLUTTER:-0}"

if [[ "${SKIP_GIT_PULL}" != "1" ]]; then
  echo "[NEXUS] git pull --ff-only..."
  git pull --ff-only
fi

if [[ "${SKIP_DOCKER}" != "1" ]]; then
  if [[ ! -f ".env" ]]; then
    echo "[NEXUS] Нет .env в ${ROOT} — скопируйте: cp .env.example .env и задайте JWT_SECRET, CORS_ALLOWED_ORIGINS."
    exit 1
  fi
  echo "[NEXUS] docker compose up -d --build..."
  docker compose up -d --build
fi

if [[ "${SKIP_ADMIN}" != "1" ]] && [[ -d "admin-panel" ]]; then
  if command -v npm >/dev/null 2>&1; then
    echo "[NEXUS] admin-panel: npm ci && npm run build..."
    (cd admin-panel && npm ci && npm run build)
    echo "[NEXUS] Готово: admin-panel/dist/ — раздавайте через nginx или статику."
  else
    echo "[NEXUS] Предупреждение: каталог admin-panel есть, но npm не найден. Установите Node.js LTS или задайте SKIP_ADMIN=1."
  fi
fi

if [[ "${BUILD_FLUTTER}" == "1" ]] && [[ -d "client" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    echo "[NEXUS] Flutter: pub get && build apk..."
    (cd client && flutter pub get && flutter build apk --release)
  else
    echo "[NEXUS] BUILD_FLUTTER=1, но flutter не в PATH." >&2
    exit 1
  fi
fi

if [[ "${SKIP_DOCKER}" != "1" ]]; then
  echo ""
  docker compose ps
  echo ""
  echo "[NEXUS] Проверка API: curl -sS http://127.0.0.1:8080/health"
fi
