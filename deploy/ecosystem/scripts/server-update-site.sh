#!/usr/bin/env bash
# Обновление: git pull + deploy без docker pull (обход rate limit Docker Hub).
set -euo pipefail

DEPLOY_ROOT="${DEPLOY_ROOT:-/opt/waypoint}"
PO_ROOT="${PO_ROOT:-$DEPLOY_ROOT/redik}"
ECO="${ECO:-$PO_ROOT/deploy/ecosystem}"
SMTP_FILE="${SMTP_FILE:-$DEPLOY_ROOT/smtp.env}"

[[ $EUID -eq 0 ]] || { echo "Запуск: sudo bash $0"; exit 1; }

if [[ -d "$PO_ROOT/.git" ]]; then
  git -C "$PO_ROOT" fetch origin
  git -C "$PO_ROOT" checkout -f main
  git pull --ff-only origin main || git -C "$PO_ROOT" reset --hard origin/main
fi

if [[ -f "$SMTP_FILE" ]]; then
  python3 - <<'PY'
import re
p = "/opt/waypoint/smtp.env"
t = open(p, encoding="utf-8").read()
open(p, "w", encoding="utf-8").write(re.sub(r"\$(?!\$)", "$$", t))
PY
fi

export GITHUB_REPO="${GITHUB_REPO:-Alegro-s/redisant}"
export SKIP_SMTP_CHECK="${SKIP_SMTP_CHECK:-1}"
chmod +x "$ECO/scripts/"*.sh
"$ECO/scripts/server-02-clone-github-redik.sh"

curl -fsS http://127.0.0.1:8090/health && echo " auth OK" || echo " auth FAIL — docker logs waypoint-auth-api"
curl -fsS http://127.0.0.1:8080/health && echo " waypoint OK" || true
curl -fsS http://127.0.0.1:8082/health && echo " lynx OK" || true
echo "Done."
