
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[NEXUS] Обновление индекса пакетов и установка обновлений (может занять время)..."
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  ca-certificates \
  curl \
  git \
  gnupg \
  rsync \
  unzip \
  htop \
  ufw \
  software-properties-common

echo "[NEXUS] Часовой пояс (при необходимости: timedatectl set-timezone Europe/Moscow)"
timedatectl status || true

if [[ "${SKIP_UFW:-0}" != "1" ]]; then
  echo "[NEXUS] UFW: SSH (22) и API NEXUS (8080)..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp comment 'SSH'
  ufw allow 8080/tcp comment 'NEXUS API'
  for p in ${EXTRA_UFW_PORTS:-}; do
    [[ -z "$p" ]] && continue
    ufw allow "${p}/tcp" || true
  done
  ufw --force enable
  ufw status verbose
else
  echo "[NEXUS] UFW пропущен (SKIP_UFW=1)"
fi

if [[ "${CREATE_DEPLOY_USER:-0}" == "1" ]]; then
  if ! id nexus &>/dev/null; then
    adduser --disabled-password --gecos "" nexus
    echo "[NEXUS] Пользователь nexus создан. Задайте пароль: passwd nexus"
  fi
  usermod -aG sudo nexus
  mkdir -p /home/nexus/.ssh
  chmod 700 /home/nexus/.ssh
  if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    echo "$SSH_PUBLIC_KEY" >> /home/nexus/.ssh/authorized_keys
    chmod 600 /home/nexus/.ssh/authorized_keys
    chown -R nexus:nexus /home/nexus/.ssh
    echo "[NEXUS] SSH-ключ добавлен для nexus"
  fi
  echo "[NEXUS] Вход по SSH: ssh nexus@<IP> (пароль: passwd nexus)"
fi

echo ""
echo "[NEXUS] Фаза 1 завершена."
echo "  Дальше: git clone репозиторий, затем Docker (scripts/vps-bootstrap.sh или ваш compose)."
echo "  Смена пароля root (если ещё не делали): bash scripts/vps-change-root-password.sh"
