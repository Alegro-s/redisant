set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

as_root() {
  if [[ "${EUID:-0}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "[lynx-vps] Нужна команда: $1" >&2; exit 1; }; }

LYNX_CLOUD_UNIT="${LYNX_CLOUD_UNIT:-lynx-cloud-next.service}"
LYNX_ENSURE_SYSTEMD="${LYNX_ENSURE_SYSTEMD:-1}"

ensure_systemd_nextjs() {
  if [[ "${LYNX_ENSURE_SYSTEMD}" != "1" ]]; then
    return 0
  fi
  need systemctl
  local unit_path="/etc/systemd/system/${LYNX_CLOUD_UNIT}"
  if [[ -f "${unit_path}" ]]; then
    return 0
  fi
  need npm
  local npm_bin
  npm_bin="$(command -v npm)"
  if [[ -z "${npm_bin}" ]]; then
    echo "[lynx-vps] npm не найден — не могу создать systemd unit." >&2
    exit 1
  fi
  echo "[lynx-vps] Создаю ${unit_path} (первый запуск)..."
  as_root tee "${unit_path}" >/dev/null <<EOF
[Unit]
Description=Lynx Cloud (Next.js), порт 3001
After=network.target

[Service]
Type=simple
WorkingDirectory=${ROOT}/cloud
Environment=NODE_ENV=production
ExecStart=${npm_bin} run start
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  as_root systemctl daemon-reload
  as_root systemctl enable "${LYNX_CLOUD_UNIT}"
}

ensure_systemd_nextjs

export LYNX_CLOUD_SYSTEMD="${LYNX_CLOUD_UNIT}"
export RELOAD_NGINX="${RELOAD_NGINX:-1}"

exec bash "${ROOT}/scripts/lynx-server-deploy.sh"
