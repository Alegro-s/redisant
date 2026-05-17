
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "======== [1/4] Пакеты и обновления ========"
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

echo "======== [2/4] Firewall (ufw) ========"
if [[ "${SKIP_UFW:-0}" != "1" ]]; then
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
  echo "UFW пропущен (SKIP_UFW=1)"
fi

echo "======== Пользователь для деплоя (опционально) ========"
if [[ "${CREATE_DEPLOY_USER:-0}" == "1" ]]; then
  if ! id nexus &>/dev/null; then
    adduser --disabled-password --gecos "" nexus
    echo "Пользователь nexus создан. Задайте пароль: passwd nexus"
  fi
  usermod -aG sudo nexus
  mkdir -p /home/nexus/.ssh
  chmod 700 /home/nexus/.ssh
  if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
    grep -qxF "$SSH_PUBLIC_KEY" /home/nexus/.ssh/authorized_keys 2>/dev/null || echo "$SSH_PUBLIC_KEY" >> /home/nexus/.ssh/authorized_keys
    chmod 600 /home/nexus/.ssh/authorized_keys
    chown -R nexus:nexus /home/nexus/.ssh
    echo "SSH-ключ добавлен для nexus"
  fi
fi

echo "======== [3/4] Docker Engine + Compose ========"
if ! command -v docker &>/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"

OWNER="${NEXUS_CLONE_USER:-${SUDO_USER:-}}"
[[ "$OWNER" == "root" || -z "$OWNER" ]] && OWNER=""
if [[ -n "$OWNER" ]] && id "$OWNER" &>/dev/null; then
  usermod -aG docker "$OWNER" || true
  echo "Пользователь $OWNER добавлен в группу docker (перелогиньтесь или: newgrp docker)"
fi

echo "======== [4/4] Клон NEXUS (если задан NEXUS_CLONE_URL) ========"
NEXUS_DIR="${NEXUS_DIR:-/opt/nexus}"
if [[ -n "${NEXUS_CLONE_URL:-}" ]]; then
  if [[ -d "$NEXUS_DIR/.git" ]]; then
    echo "Уже есть репозиторий в $NEXUS_DIR — клон пропущен."
  else
    mkdir -p "$(dirname "$NEXUS_DIR")"
    git clone --depth 1 "$NEXUS_CLONE_URL" "$NEXUS_DIR"
    if [[ -n "$OWNER" ]]; then
      chown -R "$OWNER:$OWNER" "$NEXUS_DIR"
    fi
  fi

  if [[ ! -f "$NEXUS_DIR/.env" ]] && [[ -f "$NEXUS_DIR/.env.example" ]]; then
    cp "$NEXUS_DIR/.env.example" "$NEXUS_DIR/.env"
    echo "Создан $NEXUS_DIR/.env из примера — ОБЯЗАТЕЛЬНО отредактируйте JWT_SECRET и CORS_ALLOWED_ORIGINS"
  fi

  if [[ "${AUTO_COMPOSE:-0}" == "1" ]]; then
    if [[ -f "$NEXUS_DIR/.env" ]] && grep -qE '^JWT_SECRET=.{32,}' "$NEXUS_DIR/.env"; then
      (cd "$NEXUS_DIR" && docker compose up -d --build)
      echo "Compose запущен. Проверка: curl -sS http://127.0.0.1:8080/health"
    else
      echo "AUTO_COMPOSE пропущен: в $NEXUS_DIR/.env нет JWT_SECRET длиной ≥32 символов."
    fi
  fi
else
  echo "NEXUS_CLONE_URL не задан — клон пропущен."
fi

echo ""
echo "======== Готово ========"
echo "Дальше вручную (если ещё не сделали):"
echo "  1) git clone ... в каталог, например $NEXUS_DIR"
echo "  2) cd $NEXUS_DIR && cp .env.example .env && nano .env"
echo "     — JWT_SECRET (openssl rand -base64 32)"
echo "     — CORS_ALLOWED_ORIGINS=http://ВАШ_IP:8080,..."
echo "  3) cd $NEXUS_DIR && docker compose up -d --build"
echo "  4) curl -sS http://127.0.0.1:8080/health"
echo ""
echo "Тонкий клон в одну строку (меньше нагрузка на RAM):"
echo "  git clone --depth 1 <URL> $NEXUS_DIR"
