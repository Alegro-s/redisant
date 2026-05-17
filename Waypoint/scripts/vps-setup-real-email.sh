
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Запустите от root (sudo)."; exit 1; }

NEXUS_ROOT="${NEXUS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MERGE_NEXUS_ENV="${MERGE_NEXUS_ENV:-1}"
MAIL_ENV_FILE="${MAIL_ENV_FILE:-}"

if [[ -n "$MAIL_ENV_FILE" && -f "$MAIL_ENV_FILE" ]]; then
  set -a
  source "$MAIL_ENV_FILE"
  set +a
fi

require() {
  local n="$1"
  if [[ -z "${!n:-}" ]]; then
    echo "Не задана обязательная переменная: $n (export или файл MAIL_ENV_FILE)." >&2
    exit 1
  fi
}

require SMTP_HOST
require SMTP_PORT
require SMTP_USER
require SMTP_PASSWORD
require SMTP_FROM_EMAIL
require OTP_WEBHOOK_SECRET
require PUBLIC_WEB_BASE_URL

NEXUS_MAIL_FROM="${NEXUS_MAIL_FROM:-${SMTP_FROM_EMAIL}}"
OTP_WEBHOOK_URL="${OTP_WEBHOOK_URL:-http://host.docker.internal:9090/send-otp.php}"
SYSTEMD_NAME="nexus-otp-webhook"
ENV_DROPIN="/etc/${SYSTEMD_NAME}.env"
MSMTPRC="/etc/msmtprc"
WEBHOOK_DIR="${NEXUS_ROOT}/integrations/otp-webhook"

[[ -f "${WEBHOOK_DIR}/send-otp.php" ]] || {
  echo "Не найден ${WEBHOOK_DIR}/send-otp.php — проверьте NEXUS_ROOT=$NEXUS_ROOT" >&2
  exit 1
}

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq msmtp msmtp-mta ca-certificates php-cli curl python3

MSMT_PASS_FILE="/root/.msmtp-nexus-pass"
umask 077
printf '%s' "$SMTP_PASSWORD" > "$MSMT_PASS_FILE"
chmod 600 "$MSMT_PASS_FILE"
chown root:root "$MSMT_PASS_FILE"

if [[ "${SMTP_PORT}" == "465" ]]; then
  MSMTP_TLS_STARTTLS="off"
else
  MSMTP_TLS_STARTTLS="on"
fi

cat > "$MSMTPRC" << EOF
defaults
auth           on
tls            on
tls_starttls   ${MSMTP_TLS_STARTTLS}
tls_trust_file /etc/ssl/certs/ca-certificates.crt
syslog         on

account        nexus
host           ${SMTP_HOST}
port           ${SMTP_PORT}
from           ${SMTP_FROM_EMAIL}
user           ${SMTP_USER}
passwordeval   cat ${MSMT_PASS_FILE}

account default : nexus
EOF
chmod 600 "$MSMTPRC"
chown root:root "$MSMTPRC"

ENV_DROPIN="$ENV_DROPIN" OTP_WEBHOOK_SECRET="$OTP_WEBHOOK_SECRET" NEXUS_MAIL_FROM="$NEXUS_MAIL_FROM" \
python3 - <<'PY'
import os, pathlib
def esc_systemd_quoted(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')
sec = os.environ["OTP_WEBHOOK_SECRET"]
mail = os.environ["NEXUS_MAIL_FROM"]
path = pathlib.Path(os.environ["ENV_DROPIN"])
path.write_text(
    f'NEXUS_OTP_WEBHOOK_SECRET="{esc_systemd_quoted(sec)}"\n'
    f'NEXUS_MAIL_FROM="{esc_systemd_quoted(mail)}"\n',
    encoding="utf-8",
)
os.chmod(path, 0o600)
PY
chown root:root "$ENV_DROPIN"

cat > "/etc/systemd/system/${SYSTEMD_NAME}.service" << EOF
[Unit]
Description=NEXUS OTP / email verification webhook (PHP)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=${ENV_DROPIN}
WorkingDirectory=${WEBHOOK_DIR}
ExecStart=/usr/bin/php -S 0.0.0.0:9090 -t ${WEBHOOK_DIR}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "${SYSTEMD_NAME}.service"

upsert_env_kv() {
  local file="$1" key="$2" val="$3"
  [[ -f "$file" ]] || touch "$file"
  local tmp
  tmp=$(mktemp)
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    grep -v "^${key}=" "$file" > "$tmp" || true
  else
    cp "$file" "$tmp"
  fi
  mv "$tmp" "$file"
  printf '%s=%s\n' "$key" "$val" >> "$file"
}

ENV_FILE="${NEXUS_ROOT}/.env"
if [[ "$MERGE_NEXUS_ENV" == "1" ]]; then
  upsert_env_kv "$ENV_FILE" "PUBLIC_WEB_BASE_URL" "$PUBLIC_WEB_BASE_URL"
  upsert_env_kv "$ENV_FILE" "OTP_WEBHOOK_URL" "$OTP_WEBHOOK_URL"
  upsert_env_kv "$ENV_FILE" "OTP_WEBHOOK_SECRET" "$OTP_WEBHOOK_SECRET"
  if grep -q '^OTP_LOG_CODES=' "$ENV_FILE" 2>/dev/null; then
    upsert_env_kv "$ENV_FILE" "OTP_LOG_CODES" "0"
  fi
fi

echo ""
echo "=== Готово ==="
echo "Сервис: systemctl status ${SYSTEMD_NAME}"
echo "Логи вебхука: journalctl -u ${SYSTEMD_NAME} -f"
echo "Логи msmtp: journalctl -t msmtp -f   (или grep msmtp /var/log/syslog)"
echo "MSMTP: $MSMTPRC"
echo "Webhook: $OTP_WEBHOOK_URL (секрет в X-Nexus-Webhook-Secret)"
if [[ "$MERGE_NEXUS_ENV" == "1" ]]; then
  echo "Обновлён $ENV_FILE — перезапустите API: cd $NEXUS_ROOT && docker compose up -d"
fi
echo ""
echo "Проверка SMTP (подставьте свой ящик):"
echo "  printf 'Subject: NEXUS msmtp test\\n\\nok\\n' | msmtp -a default ваш@email.ru"
echo ""
echo "Безопасность: порт 9090 слушает все интерфейсы (нужно для Docker bridge). Закройте его снаружи:"
echo "  ufw status; ufw deny 9090/tcp   # и разрешите только SSH/80/443 как у вас принято"
echo "  (API в Docker ходит на вебхук через host.docker.internal — см. docker-compose.yml extra_hosts)"
echo ""
