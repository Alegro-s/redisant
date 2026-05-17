#!/usr/bin/env bash
# Локально (Windows: Git Bash / WSL). Экспорт монорепо PO в отдельные каталоги для GitHub.
# После запуска: в каждом каталоге git init, remote add, push.

set -euo pipefail
PO_ROOT="${PO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
OUT="${OUT:-$PO_ROOT/_github_export}"
rm -rf "$OUT"
mkdir -p "$OUT"

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  rsync -a --exclude node_modules --exclude target --exclude dist --exclude .next "$src/" "$dst/"
}

echo "PO_ROOT=$PO_ROOT"
echo "OUT=$OUT"

# auth: platform/server + compose
mkdir -p "$OUT/waypoint-auth"
copy_tree "$PO_ROOT/platform/server" "$OUT/waypoint-auth/platform/server"
cp "$PO_ROOT/deploy/ecosystem/docker-compose.auth.yml" "$OUT/waypoint-auth/docker-compose.yml"
cp "$PO_ROOT/deploy/ecosystem/scripts/email-webhook-smtp.py" "$OUT/waypoint-auth/email-webhook-smtp.py"
mkdir -p "$OUT/waypoint-auth/scripts"
mv "$OUT/waypoint-auth/email-webhook-smtp.py" "$OUT/waypoint-auth/scripts/"
# fix compose paths for single-repo layout
sed -i 's|../../platform/server|./platform/server|g' "$OUT/waypoint-auth/docker-compose.yml" 2>/dev/null || \
  sed -i '' 's|../../platform/server|./platform/server|g' "$OUT/waypoint-auth/docker-compose.yml"

# apis
mkdir -p "$OUT/waypoint-apis/platform/server"
copy_tree "$PO_ROOT/platform/server" "$OUT/waypoint-apis/platform/server"
cp "$PO_ROOT/deploy/ecosystem/docker-compose.apis.yml" "$OUT/waypoint-apis/docker-compose.yml"
sed -i 's|../../platform/server|./platform/server|g' "$OUT/waypoint-apis/docker-compose.yml" 2>/dev/null || \
  sed -i '' 's|../../platform/server|./platform/server|g' "$OUT/waypoint-apis/docker-compose.yml"

copy_tree "$PO_ROOT/Waypoint/web" "$OUT/waypoint-club-web"
echo 'VITE_PUBLIC_SITE_MODE=club' > "$OUT/waypoint-club-web/.env.production"

copy_tree "$PO_ROOT/Waypoint/web" "$OUT/waypoint-metric-web"
echo 'VITE_PUBLIC_SITE_MODE=metric' > "$OUT/waypoint-metric-web/.env.production"

copy_tree "$PO_ROOT/Lynx/hub" "$OUT/lynx-hub"
copy_tree "$PO_ROOT/Lynx/cloud" "$OUT/lynx-cloud"
copy_tree "$PO_ROOT/roza" "$OUT/roza"
copy_tree "$PO_ROOT/roza/web" "$OUT/roza-web"

cat <<'EOF'

Экспорт в: _github_export/

Для каждого репозитория на GitHub:
  cd _github_export/waypoint-auth
  git init && git add -A && git commit -m "Initial import"
  gh repo create waypoint-auth --private --source=. --push

Перед деплоем на VPS очистите старые репозитории на GitHub (Settings → Delete repository)
или создайте новые имена в repos.env.

EOF
