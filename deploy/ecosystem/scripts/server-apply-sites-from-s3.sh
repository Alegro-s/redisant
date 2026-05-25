#!/usr/bin/env bash
# Применить статику с Timeweb S3 (после upload-sites-s3.ps1 на ПК).
#   sudo bash deploy/ecosystem/scripts/server-apply-sites-from-s3.sh
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
S3_SECRETS="${S3_SECRETS:-$DEPLOY_ROOT/s3.secrets}"
S3_ENDPOINT="${S3_ENDPOINT:-https://s3.twcstorage.ru}"
S3_BUCKET="${S3_BUCKET:-bc39a46d-ee3d-4707-9e3f-9529afb602da}"
S3_PREFIX="${S3_PREFIX:-deploy/sites/latest/}"
TMP="${TMP:-/tmp/waypoint-sites-bundle}"

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash $0"; exit 1; }

if [[ -f "$S3_SECRETS" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$S3_SECRETS"
  set +a
fi

if ! command -v aws >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq awscli || apt-get install -y -qq awscli
fi

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ru-1}"
mkdir -p "$TMP"
echo "==> S3 sync s3://${S3_BUCKET}/${S3_PREFIX} -> $TMP"
aws s3 sync "s3://${S3_BUCKET}/${S3_PREFIX}" "$TMP" --endpoint-url "$S3_ENDPOINT"

apply() {
  local name="$1"
  local dst="$2"
  if [[ ! -d "$TMP/$name" ]]; then
    echo "  SKIP $name (нет в бандле)"
    return
  fi
  mkdir -p "$dst"
  rsync -a --delete "$TMP/$name/" "$dst/"
  echo "  OK $name -> $dst"
}

echo "==> rsync на /srv"
apply waypoint-club /srv/waypointclub/web
apply waypoint-metric /srv/waypointmetric/dist
apply lynx-hub /srv/lynx-hub/dist
apply roza /srv/roza/web/roza

if [[ -f /srv/waypointclub/web/favicon-club.svg ]]; then
  cp -f /srv/waypointclub/web/favicon-club.svg /srv/waypointclub/web/favicon.svg 2>/dev/null || true
fi
if [[ -f /srv/waypointmetric/dist/favicon-metric.svg ]]; then
  cp -f /srv/waypointmetric/dist/favicon-metric.svg /srv/waypointmetric/dist/favicon.svg 2>/dev/null || true
fi

nginx -t && systemctl reload nginx

echo ""
echo "Готово. Проверка:"
echo "  https://waypointclub.ru/"
echo "  https://waypointclub.ru/roza/security"
echo "  https://metrika-waypoint.ru/"
echo "  https://lynx-hub.ru/"
