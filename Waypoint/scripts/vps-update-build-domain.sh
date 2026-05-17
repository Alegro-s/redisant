
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash $0"
  exit 1
fi

DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"
NEXUS_DIR="${NEXUS_DIR:-/opt/nexus}"
APP_PORT="${APP_PORT:-8080}"
ENABLE_UFW="${ENABLE_UFW:-1}"

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "Нужно задать DOMAIN и EMAIL."
  echo "Пример: sudo DOMAIN=api.example.com EMAIL=admin@example.com bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/7] Обновление системы ==="
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl git gnupg lsb-release software-properties-common nginx certbot python3-certbot-nginx

echo "=== [2/7] Docker (если не установлен) ==="
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

echo "=== [3/7] Firewall ==="
if [[ "$ENABLE_UFW" == "1" ]]; then
  ufw allow 22/tcp || true
  ufw allow 80/tcp || true
  ufw allow 443/tcp || true
  ufw allow "${APP_PORT}/tcp" || true
  ufw --force enable || true
fi

echo "=== [4/7] Обновление проекта и билд ==="
if [[ ! -d "$NEXUS_DIR/.git" ]]; then
  echo "Не найден git-репозиторий в $NEXUS_DIR"
  echo "Сначала загрузите проект на сервер (git clone / rsync)."
  exit 1
fi

cd "$NEXUS_DIR"
if [[ ! -f ".env" ]]; then
  echo "В $NEXUS_DIR нет .env. Создайте его из .env.example."
  exit 1
fi

git fetch --all --prune
git pull --ff-only

docker compose up -d --build

echo "Проверка backend локально..."
curl -fsS "http://127.0.0.1:${APP_PORT}/health" >/dev/null
echo "OK: backend отвечает на 127.0.0.1:${APP_PORT}"

echo "=== [5/7] Nginx reverse proxy для домена ==="
cat >/etc/nginx/sites-available/nexus.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

ln -sf /etc/nginx/sites-available/nexus.conf /etc/nginx/sites-enabled/nexus.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "=== [6/7] Let's Encrypt сертификат ==="
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect

echo "=== [7/7] Финальные проверки ==="
systemctl reload nginx
curl -fsS "https://${DOMAIN}/health" >/dev/null
echo "OK: https://${DOMAIN}/health отвечает"

echo ""
echo "Готово."
echo "Домен подключен: https://${DOMAIN}"
echo "Проект обновлен и перезапущен из: ${NEXUS_DIR}"
