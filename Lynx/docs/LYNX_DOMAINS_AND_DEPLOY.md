# Lynx: домены и прод-сцепка

Целевая схема: **несколько сайтов + PWA + API** на одном сервере (актуальные прод-имена):

| Хост | Что это |
|------|---------|
| `lynx-hub.ru` | Публичный сайт Lynx Hub (`nexus-hab`) |
| `lynx-cloud.ru` | Технический портал Lynx Cloud (`nexus-cloud`) |
| `metrika-waypoint.ru` | WaypointMetric (`admin-panel`) + установка как PWA |
| `api.lynx-cloud.ru` | Один Rust API (`server`) для Lynx / WaypointMetric |
| `waypointclub.ru` | Профиль ТулГУ / Flutter Web (`tsput_profile`), API на `127.0.0.1:8081` |

Ранее в шаблоне использовалось `metric.lynx-cloud.ru` — при миграции замените в DNS и в `.env` на `metrika-waypoint.ru`.

## 0) DNS обязан указывать на **этот** VPS

Перед `lynx-vps-provision-public.sh` все перечисленные ниже имена должны резолвиться в **тот же IPv4**, что и у сервера (проверка в скрипте). Иначе сайты откроются на другой машине, а Let’s Encrypt не выпустит сертификат.

Если DNS ещё старый, временно: `SKIP_DNS_CHECK=1 SKIP_CERTBOT=1 ./scripts/lynx-vps-provision-public.sh` (HTTP без выпуска TLS), затем повторить без `SKIP_*` после смены A-записей.

Конфликт **`git pull`**: локальные правки в `scripts/server-stack/` — выполните `scripts/server-stack/sync-from-remote.sh` из корня клона (или `git checkout origin/main -- scripts/server-stack/` и `git pull`).

## 1) Рекомендуемые env по проектам

### `server/.env`

```env
BIND_ADDRESS=0.0.0.0:8080
CORS_ALLOWED_ORIGINS=https://lynx-hub.ru,https://www.lynx-hub.ru,https://lynx-cloud.ru,https://www.lynx-cloud.ru,https://metrika-waypoint.ru,https://www.metrika-waypoint.ru,https://waypointclub.ru,https://www.waypointclub.ru
PUBLIC_WEB_BASE_URL=https://metrika-waypoint.ru
# Почта при критичных логах Waypoint ingest (тот же OTP_WEBHOOK_URL → integrations/otp-webhook/send-otp.php):
# WAYPOINT_ALERT_EMAIL_TO=ops@example.com
```

### `admin-panel/.env`

```env
# Рекомендуется проксировать API под тем же доменом PWA:
VITE_API_URL=/api

# Опционально (кнопка "Установить нативно"):
VITE_ANDROID_APP_URL=https://lynx-hub.ru/download
VITE_IOS_APP_URL=https://lynx-hub.ru/download
```

### `nexus-cloud/.env`

```env
NEXT_PUBLIC_LYNX_API_BASE=https://api.lynx-cloud.ru
NEXT_PUBLIC_WAYPOINT_CONSOLE_URL=https://metrika-waypoint.ru
NEXT_PUBLIC_LYNX_HUB_URL=https://lynx-hub.ru
```

### `nexus-hab/.env`

```env
VITE_LYNX_CLOUD_URL=https://lynx-cloud.ru
VITE_WAYPOINT_CONSOLE_URL=https://metrika-waypoint.ru
VITE_ENGINE_MANIFEST_URL=https://api.lynx-cloud.ru/engine/manifest
# После публикации релизов (скрипт scripts/build-lynx-client-on-pc.ps1):
# VITE_LYNX_LAUNCHER_EXE_URL=https://…/…exe
# VITE_LYNX_LAUNCHER_APK_URL=https://…/app-release.apk
# VITE_LYNX_SOURCES_ZIP_URL=https://…/lynx-launcher-sources.zip
```

## 2) Nginx (единый reverse proxy)

Готовый шаблон: `docs/NGINX_PROD_3_SITES_1_APP.conf`.

Схема:
- `lynx-hub.ru` -> статика `nexus-hab/dist`
- `lynx-cloud.ru` -> upstream Next.js (`127.0.0.1:3001`)
- `metrika-waypoint.ru` -> статика `admin-panel/dist` + `location /api/` к Rust API
- `api.lynx-cloud.ru` -> Rust API (`127.0.0.1:8080`)
- `waypointclub.ru` -> статика `/srv/waypointclub/web` + `/api/` к FastAPI (`127.0.0.1:8081`, см. `tsput_profile/docker-compose.bind-local-api.yml`)

В шаблоне для порта **80** добавлен `location ^~ /.well-known/acme-challenge/` с `root /var/www/certbot`. Без этого certbot получает **404** (хаб: `try_files` уводит в SPA) и **502** (cloud: запрос уходит в Next).

### DNS (обязательно до certbot)

В зоне **`lynx-cloud.ru`** заведите **A** на IP VPS (частая ошибка — только корень зоны, без поддоменов):

- `api.lynx-cloud.ru` → A  
- `metrika-waypoint.ru`, `www.metrika-waypoint.ru` → A  
- `waypointclub.ru`, `www.waypointclub.ru` → A  

Плюс **A** для `lynx-hub.ru`, `www`, `lynx-cloud.ru`, `www` — как у вас принято. Пока `dig +short api.lynx-cloud.ru` (или нового хоста) пусто, Let’s Encrypt вернёт **NXDOMAIN**.

Автоматизация на VPS (после того как A-записи ведут на IP сервера): `scripts/lynx-vps-provision-public.sh` — ставит `docs/NGINX_PROD_3_SITES_1_APP.conf`, проверяет DNS, `certbot --nginx`, затем `lynx-vps-all-up.sh`.

### Сертификат (webroot, надёжнее плагина nginx на SPA)

```bash
sudo mkdir -p /var/www/certbot
sudo nginx -t && sudo systemctl reload nginx
sudo certbot certonly --webroot -w /var/www/certbot \
  -d lynx-hub.ru -d www.lynx-hub.ru \
  -d lynx-cloud.ru -d www.lynx-cloud.ru \
  -d api.lynx-cloud.ru \
  -d metrika-waypoint.ru -d www.metrika-waypoint.ru \
  -d waypointclub.ru -d www.waypointclub.ru
sudo certbot install --nginx --cert-name lynx-hub.ru --redirect
```

Не используйте **`certbot --nginx`** для выпуска, если в конфиге уже есть `location ^~ /.well-known/acme-challenge/` с `root /var/www/certbot` — плагин даёт **404** на проверке LE. Схема: **certonly --webroot**, затем **install --nginx**.

Если **`curl http://127.0.0.1/.well-known/...` с `Host:` даёт 200**, а **`curl http://ВАШ_ПУБЛИЧНЫЙ_IP/...` — 404**, сначала проверьте **с внешней сети** (`curl` с телефона/другого сервера на `http://lynx-hub.ru/.well-known/...`): с самой ВМ путь часто **не совпадает** с путём Let's Encrypt (hairpin, LXC/NAT). Возможна и строка **`listen ВАШ_IP:80 default_server`** в старом vhost — тогда **`LYNX_AUTO_FIX_LISTEN_IP=1`** или замена на **`listen 80;`**.

Фрагмент для `include`: `docs/nginx-snippet-letsencrypt-acme.conf` (одна строка в каждый `server` на порту 80).

Проверка до certbot (должно быть **200** с телом `ok`):

```bash
sudo mkdir -p /var/www/certbot/.well-known/acme-challenge
printf ok | sudo tee /var/www/certbot/.well-known/acme-challenge/ping
curl -sS -D- http://127.0.0.1/.well-known/acme-challenge/ping -H "Host: lynx-hub.ru" | head -5
curl -sS -D- http://127.0.0.1/.well-known/acme-challenge/ping -H "Host: lynx-cloud.ru" | head -5
```

Если здесь **404** или **502**, смотрите активный конфиг: `sudo nginx -T | grep -E 'server_name|well-known|lynx-hub|lynx-cloud'`.

Если nginx-пазл не сходится быстро, временный обход (**краткий простой** на 80 порту, certbot сам поднимает сервер):

```bash
sudo systemctl stop nginx
sudo certbot certonly --standalone -d lynx-hub.ru -d www.lynx-hub.ru -d lynx-cloud.ru -d www.lynx-cloud.ru
sudo systemctl start nginx
```

Потом пропишите пути к `fullchain.pem` / `privkey.pem` в блоках `listen 443 ssl` (как в выводе certbot).

## 3) PWA (приложение)

PWA = сайт `metrika-waypoint.ru`, установленный на устройство.

- `manifest.webmanifest` уже привязан к WaypointMetric.
- `sw.js` кэширует статику и SPA-shell.
- API (`/me/*`, `/api/*`) не кэшируется: данные всегда живые.

## 4) Манифест ядра и сборки

- Приоритет env для встроенного JSON: `LYNX_ENGINE_MANIFEST_JSON`, затем `NEXUS_ENGINE_MANIFEST_JSON`.
- Секрет worker: `LYNX_BUILD_WORKER_SECRET` или `NEXUS_BUILD_WORKER_SECRET`.
- Заголовки: `X-Lynx-Build-Worker-Secret` / `X-Nexus-Build-Worker-Secret`.
- Отчёт: `POST /integrations/lynx-cloud/build-report`.

## 5) SEO и защита

- Для Lynx Hub: уникальные `title`/`description`, `robots.txt`, sitemap при необходимости.
- Для статики на nginx: `expires` для `assets/*`.
- Rate-limit: минимум для `/login`, `/register`, `POST /api/waypoint/ingest`.
- Защита периметра: Cloudflare (WAF + TLS + кэш статики).

## 6) API-алиасы Lynx Cloud

Маршруты `/me/lynx-cloud/*` дублируют `/me/nexus-cloud/*` (единая БД). Новые клиенты должны использовать `lynx-cloud`.
