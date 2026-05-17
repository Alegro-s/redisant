
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Запустите с sudo: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl ca-certificates gnupg

if ! command -v docker &>/dev/null; then
  echo "[NEXUS] Установка Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "[NEXUS] Docker: $(docker --version)"
echo "[NEXUS] Compose: $(docker compose version)"

DEPLOY_USER="${SUDO_USER:-$USER}"
if [[ "$DEPLOY_USER" != "root" ]] && id "$DEPLOY_USER" &>/dev/null; then
  usermod -aG docker "$DEPLOY_USER" || true
  echo "[NEXUS] Пользователь $DEPLOY_USER добавлен в группу docker (перелогиньтесь или newgrp docker)."
fi

echo ""
echo "[NEXUS] Дальше вручную:"
echo "  1) git clone <URL_вашего_репозитория> && cd NEXUS"
echo "  2) cp .env.example .env && nano .env   # JWT_SECRET (≥32), CORS_ALLOWED_ORIGINS с IP/доменом"
echo "  3) ufw allow 22/tcp && ufw allow 8080/tcp && ufw enable   # если используете ufw"
echo "  4) ./scripts/vps-deploy.sh"
echo ""
echo "Опционально клон одной строкой (публичный репозиторий):"
echo "  export NEXUS_CLONE_URL=https://github.com/USER/NEXUS.git"
echo "  export NEXUS_DIR=/opt/nexus"
echo "  git clone \"\$NEXUS_CLONE_URL\" \"\$NEXUS_DIR\" && chown -R \"\$DEPLOY_USER:\$DEPLOY_USER\" \"\$NEXUS_DIR\""
