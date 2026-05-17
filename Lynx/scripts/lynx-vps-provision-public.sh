set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LYNX_HOSTS=(
  lynx-hub.ru
  www.lynx-hub.ru
  lynx-cloud.ru
  www.lynx-cloud.ru
  api.lynx-cloud.ru
  metrika-waypoint.ru
  www.metrika-waypoint.ru
  waypointclub.ru
  www.waypointclub.ru
)

die() { echo "[lynx-provision] ERROR: $*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Нужна команда: $1"; }

as_root() {
  if [[ "${EUID:-0}" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

detect_public_ipv4() {
  if [[ -n "${LYNX_EXPECT_IP:-}" ]]; then
    echo "$LYNX_EXPECT_IP"
    return
  fi
  local ip=""
  ip="$(curl -4fsS --connect-timeout 5 https://api.ipify.org 2>/dev/null || true)"
  if [[ -n "$ip" ]]; then
    echo "$ip"
    return
  fi
  ip="$(curl -4fsS --connect-timeout 5 https://ifconfig.me/ip 2>/dev/null || true)"
  if [[ -n "$ip" ]]; then
    echo "$ip"
    return
  fi
  die "Не удалось определить публичный IPv4. Задайте LYNX_EXPECT_IP=ВАШ_IP"
}

resolve_v4() {
  local h="$1" ip=""
  if command -v getent >/dev/null 2>&1; then
    ip="$(getent ahosts "$h" 2>/dev/null | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+' | head -1 || true)"
  fi
  if [[ -z "$ip" ]] && command -v dig >/dev/null 2>&1; then
    ip="$(dig +short "$h" A @1.1.1.1 | grep -E '^[0-9.]+$' | tail -1 || true)"
  fi
  if [[ -z "$ip" ]] && command -v host >/dev/null 2>&1; then
    ip="$(host -t A "$h" 2>/dev/null | awk '/has address/ {print $4; exit}')"
  fi
  echo "$ip"
}

echo ""
echo "========== Lynx: куда прописать DNS =========="
EXPECT_IP="$(detect_public_ipv4)"
echo "Публичный IPv4 этого сервера (все записи ниже — на него):"
echo "  $EXPECT_IP"
echo ""
echo "Тип   Зона / поддомен              A ->"
echo "----  ---------------------------  -------------"
echo "A     lynx-hub.ru (@)              $EXPECT_IP"
echo "A     www.lynx-hub.ru              $EXPECT_IP"
echo "A     lynx-cloud.ru (@)            $EXPECT_IP"
echo "A     www.lynx-cloud.ru            $EXPECT_IP"
echo "A     api.lynx-cloud.ru            $EXPECT_IP"
echo "A     metrika-waypoint.ru          $EXPECT_IP"
echo "A     www.metrika-waypoint.ru      $EXPECT_IP"
echo "A     waypointclub.ru              $EXPECT_IP"
echo "A     www.waypointclub.ru          $EXPECT_IP"
echo ""
echo "В панели Рег.ру: отключите парковку / припарковку для lynx-hub.ru и lynx-cloud.ru,"
echo "иначе трафик уходит на OpenResty Рег.ру, а не на этот VPS."
echo "=============================================="
echo ""

SKIP_DNS_CHECK="${SKIP_DNS_CHECK:-0}"
if [[ "$SKIP_DNS_CHECK" != "1" ]]; then
  need_cmd dig
  bad=0
  for h in "${LYNX_HOSTS[@]}"; do
    r="$(resolve_v4 "$h")"
    if [[ -z "$r" ]]; then
      echo "[lynx-provision] DNS: $h -> (пусто) — нет A/не резолвится"
      bad=1
      continue
    fi
    if [[ "$r" != "$EXPECT_IP" ]]; then
      echo "[lynx-provision] DNS: $h -> $r (ожидалось $EXPECT_IP)"
      bad=1
    else
      echo "[lynx-provision] DNS OK: $h -> $r"
    fi
  done
  if [[ "$bad" -ne 0 ]]; then
    echo "" >&2
    echo "[lynx-provision] Проверка DNS не пройдена: часть имён не указывает на IP этой ВМ ($EXPECT_IP)." >&2
    echo "  Пока A-записи ведут на другой сервер, браузер и Let's Encrypt не попадут на эту машину." >&2
    echo "" >&2
    echo "  Сделайте у регистратора для ВСЕХ имён из списка выше: A -> $EXPECT_IP, подождите TTL." >&2
    echo "  Проверка с ПК: dig +short lynx-hub.ru A" >&2
    echo "" >&2
    echo "  Временно (только HTTP-nginx + полный деплой, без выпуска сертификата):" >&2
    echo "    export SKIP_DNS_CHECK=1 SKIP_CERTBOT=1" >&2
    echo "    ./scripts/lynx-vps-provision-public.sh" >&2
    echo "  После смены DNS запустите скрипт снова без SKIP_* чтобы выполнить certbot." >&2
    echo "" >&2
    die "Исправьте A-записи или используйте SKIP_DNS_CHECK=1 SKIP_CERTBOT=1 для промежуточного деплоя."
  fi
else
  echo "[lynx-provision] SKIP_DNS_CHECK=1 — проверка DNS пропущена."
fi

need_cmd nginx
as_root test -w /etc/nginx || die "Нет прав на /etc/nginx (запустите от root или sudo)"

NGINX_SITE_SRC="${ROOT}/docs/NGINX_PROD_3_SITES_1_APP.conf"
[[ -f "$NGINX_SITE_SRC" ]] || die "Нет файла $NGINX_SITE_SRC"

echo "[lynx-provision] Устанавливаю nginx: /etc/nginx/sites-available/lynx-all.conf"
as_root cp "$NGINX_SITE_SRC" /etc/nginx/sites-available/lynx-all.conf
as_root mkdir -p /etc/nginx/sites-enabled
LYNX_AVAIL="/etc/nginx/sites-available/lynx-all.conf"
for f in /etc/nginx/sites-enabled/*; do
  [[ -e "$f" ]] || continue
  if [[ -L "$f" ]] && [[ "$(readlink -f "$f")" == "$(readlink -f "$LYNX_AVAIL")" ]]; then
    as_root rm -f "$f"
  fi
done
as_root ln -sf "$LYNX_AVAIL" /etc/nginx/sites-enabled/00-lynx-all.conf

SNIP_SRC="${ROOT}/docs/nginx-snippet-letsencrypt-acme.conf"
if [[ -f "$SNIP_SRC" ]]; then
  as_root cp "$SNIP_SRC" /etc/nginx/snippets/lynx-letsencrypt-acme.conf
fi

as_root mkdir -p /var/www/certbot/.well-known/acme-challenge
as_root chmod 755 /var/www/certbot /var/www/certbot/.well-known /var/www/certbot/.well-known/acme-challenge
printf 'ok' | as_root tee /var/www/certbot/.well-known/acme-challenge/ping >/dev/null
as_root chmod 644 /var/www/certbot/.well-known/acme-challenge/ping

echo "[lynx-provision] nginx -t"
as_root nginx -t
as_root systemctl reload nginx

if [[ "${SKIP_DNS_CHECK}" != "1" ]] && command -v dig >/dev/null 2>&1; then
  for h in "${LYNX_HOSTS[@]}"; do
    aaaa="$(dig +short "$h" AAAA @1.1.1.1 | head -1 || true)"
    if [[ -n "$aaaa" ]]; then
      echo "[lynx-provision] WARN: $h имеет AAAA=$aaaa — LE может ходить по IPv6; запись должна вести на этот nginx, иначе будет 404/502. Нет IPv6 — удалите AAAA в DNS."
    fi
  done
fi

echo "[lynx-provision] Локальная проверка ACME (127.0.0.1 + Host, все ${#LYNX_HOSTS[@]} имён):"
for h in "${LYNX_HOSTS[@]}"; do
  code="$(curl -4sS -o /dev/null -w "%{http_code}" "http://127.0.0.1/.well-known/acme-challenge/ping" -H "Host: $h" || true)"
  if [[ "$code" != "200" ]]; then
    echo "[lynx-provision] Подсказка: sudo nginx -T 2>/dev/null | grep -nE 'server_name|listen 80'" >&2
    die "Локально ожидался HTTP 200 для Host=$h на /.well-known/..., получено $code. Проверьте 00-lynx-all.conf, файл sites-enabled/nexus и старые правки certbot (return 301 на уровне server до location)."
  fi
  echo "  Host $h -> $code OK"
done

if [[ "${LYNX_AUTO_FIX_LISTEN_IP:-0}" == "1" ]]; then
  IP_ESC="${EXPECT_IP//./\\.}"
  echo "[lynx-provision] LYNX_AUTO_FIX_LISTEN_IP=1: ищу listen ${EXPECT_IP}:80 в sites-enabled..."
  for f in /etc/nginx/sites-enabled/*; do
    [[ -f "$f" ]] || continue
    if grep -qE "listen[[:space:]]+${IP_ESC}:80" "$f" 2>/dev/null; then
      echo "[lynx-provision]   правлю $f → listen 80 (бэкап .bak-lynx-*)"
      as_root cp -a "$f" "${f}.bak-lynx-$(date +%s)"
      as_root sed -i "s/listen[[:space:]]\+${IP_ESC}:80/listen 80/g" "$f"
    fi
  done
  as_root nginx -t
  as_root systemctl reload nginx
fi

if [[ "${SKIP_PUBLIC_ACME_CHECK:-0}" == "1" ]]; then
  echo "[lynx-provision] SKIP_PUBLIC_ACME_CHECK=1 — блок публичного curl пропущен."
else
  echo "[lynx-provision] Проверка с этой ВМ (может отличаться от пути Let's Encrypt: hairpin, LXC, NAT):"
  PUB_VIA_IP="$(curl -4sS -o /dev/null -w "%{http_code}" "http://${EXPECT_IP}/.well-known/acme-challenge/ping" -H "Host: lynx-hub.ru" --connect-timeout 8 || true)"
  PUB_VIA_NAME="$(curl -4sS -o /dev/null -w "%{http_code}" "http://lynx-hub.ru/.well-known/acme-challenge/ping" --connect-timeout 10 || true)"
  PUB_VIA_CLOUD="$(curl -4sS -o /dev/null -w "%{http_code}" "http://lynx-cloud.ru/.well-known/acme-challenge/ping" --connect-timeout 10 || true)"
  echo "  по IP ${EXPECT_IP} + Host:lynx-hub.ru -> ${PUB_VIA_IP}"
  echo "  по имени http://lynx-hub.ru/.../ping        -> ${PUB_VIA_NAME}"
  echo "  по имени http://lynx-cloud.ru/.../ping      -> ${PUB_VIA_CLOUD}"
  PUB_OK=0
  if [[ "$PUB_VIA_IP" == "200" ]] || [[ "$PUB_VIA_NAME" == "200" ]] || [[ "$PUB_VIA_CLOUD" == "200" ]]; then
    PUB_OK=1
  fi
  if [[ "$PUB_OK" == "1" ]]; then
    echo "[lynx-provision] Публичная самопроверка: хотя бы один ответ 200."
  else
    echo "[lynx-provision] WARN: с этой ВМ все три проверки не 200 — это часто нормально (LE идёт с интернета)." >&2
    echo "  Убедитесь с телефона/внешнего хоста: curl -sS -o /dev/null -w \"%{http_code}\\n\" http://lynx-hub.ru/.well-known/acme-challenge/ping" >&2
    echo "  Диагностика: ss -tlnp | grep ':80 '" >&2
    if [[ "${STRICT_PUBLIC_ACME_CHECK:-0}" == "1" ]]; then
      die "STRICT_PUBLIC_ACME_CHECK=1 и публичный curl с ВМ не 200 — остановка."
    fi
    echo "[lynx-provision] Продолжаю certbot (снять остановку всегда: не задавать STRICT_PUBLIC_ACME_CHECK=1)."
  fi
fi

SKIP_CERTBOT="${SKIP_CERTBOT:-0}"
if [[ "$SKIP_CERTBOT" != "1" ]]; then
  need_cmd certbot
  EMAIL="${CERTBOT_EMAIL:-}"
  [[ -n "$EMAIL" ]] || die "Задайте CERTBOT_EMAIL=your@email для certbot"
  eml="${EMAIL,,}"
  if [[ "$eml" == *"ваш@"* ]] || [[ "$eml" == "you@domain.tld" ]] || [[ "$eml" == *"your@email"* ]]; then
    die "CERTBOT_EMAIL похож на заглушку из документации. Укажите реальный адрес, например: export CERTBOT_EMAIL='admin@мойдомен.ru'"
  fi
  LYNX_CERT_NAME="${LYNX_CERT_NAME:-lynx-hub.ru}"
  echo "[lynx-provision] certbot certonly --webroot -w /var/www/certbot"
  CB_EXTRA=()
  [[ "${CERTBOT_FORCE_RENEW:-0}" == "1" ]] && CB_EXTRA+=(--force-renewal)
  as_root certbot certonly --webroot -w /var/www/certbot \
    --preferred-challenges http \
    -d lynx-hub.ru -d www.lynx-hub.ru \
    -d lynx-cloud.ru -d www.lynx-cloud.ru \
    -d api.lynx-cloud.ru \
    -d metrika-waypoint.ru -d www.metrika-waypoint.ru \
    -d waypointclub.ru -d www.waypointclub.ru \
    --non-interactive --agree-tos \
    -m "$EMAIL" \
    --expand \
    "${CB_EXTRA[@]}" || {
    echo "[lynx-provision] После ошибки: ls -la /var/www/certbot/.well-known/acme-challenge/ | tail" >&2
    echo "[lynx-provision] nginx -T | sed -n '/server_name lynx-hub.ru/,/^}/p' | head -40" >&2
    die "certbot certonly не прошёл — см. выше (часто: неверный AAAA, старый return 301 от certbot, не тот vhost)."
  }
  echo "[lynx-provision] certbot install --nginx (443 + redirect)"
  as_root certbot install --nginx \
    --cert-name "$LYNX_CERT_NAME" \
    --non-interactive \
    --redirect || {
    echo "[lynx-provision] WARN: install --nginx не удался — ssl_certificate вручную: /etc/letsencrypt/live/${LYNX_CERT_NAME}/" >&2
  }
  as_root nginx -t
  as_root systemctl reload nginx
else
  echo "[lynx-provision] SKIP_CERTBOT=1 — certbot пропущен."
fi

SKIP_DEPLOY="${SKIP_DEPLOY:-0}"
if [[ "$SKIP_DEPLOY" != "1" ]]; then
  echo "[lynx-provision] Запуск полного деплоя приложения..."
  bash "${ROOT}/scripts/lynx-vps-all-up.sh"
else
  echo "[lynx-provision] SKIP_DEPLOY=1 — lynx-vps-all-up.sh не вызывался."
fi

echo ""
echo "[lynx-provision] Готово. Проверка снаружи (после DNS):"
echo "  curl -fsS https://api.lynx-cloud.ru/health"
echo "  curl -fsSI https://metrika-waypoint.ru/ | head -1"
echo "  curl -fsSI https://waypointclub.ru/ | head -1"
