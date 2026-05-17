# Полный контур: локалка и сервер (API, сайты, Nexus Cloud, движок)

Один **API** (`server`) обслуживает NEXUS, WaypointMetric (ingest, BaaS), биллинг, **`/engine/manifest`**, Nexus Cloud projects API. Фронты — отдельные процессы или статика за nginx.

## 1. Локальная разработка (Windows / Linux)

### 1.1 Корневой `.env`

Скопируйте `.env.example` → `.env`. Минимум:

```env
JWT_SECRET=<сгенерируйте_64+_символов>
ADMIN_OPEN_REGISTRATION=1

# Все origin, с которых открываете сайты в браузере (через запятую, без пробелов):
CORS_ALLOWED_ORIGINS=http://127.0.0.1:8080,http://localhost:8080,http://127.0.0.1:3000,http://localhost:3000,http://127.0.0.1:5173,http://localhost:5173,http://127.0.0.1:5175,http://localhost:5175,http://127.0.0.1:3001,http://localhost:3001

# Опционально: манифест движка одной строкой (иначе — политика в админке / URL)
# NEXUS_ENGINE_MANIFEST_JSON={"releases":[{"version":"0.1.0","notes":"local","artifacts":{"windows":{"url":"http://127.0.0.1:9000/engine/windows.zip","sha256":"REPLACE"}}}],"recommended_version":"0.1.0"}

PUBLIC_WEB_BASE_URL=http://localhost:5175
```

Для ingest rate limit и сборок подключите Redis: см. `docker-compose.override.example.yml` → `docker-compose.override.yml`.

### 1.2 API + Postgres (+ Redis)

```bash
# из корня репозитория
copy docker-compose.override.example.yml docker-compose.override.yml   # Windows
# cp docker-compose.override.example.yml docker-compose.override.yml    # Linux

docker compose up -d --build
curl -sS http://127.0.0.1:8080/health
curl -sS http://127.0.0.1:8080/engine/manifest
```

### 1.3 Сайты (отдельные терминалы)

| Продукт | Каталог | Команда | URL (типично) |
|--------|---------|---------|----------------|
| Waypoint Admin | `admin-panel/` | `npm ci && npm run dev` | http://localhost:3000 — в `vite.config` прокси `/api` → `8080` |
| Nexus Hab | `nexus-hab/` | `npm ci && npm run dev` | http://localhost:5175 |
| Nexus Cloud (Next) | `nexus-cloud/` | `npm ci && npm run dev` | http://localhost:3001 |

**Nexus Cloud** — в `.env.local`:

```env
NEXT_PUBLIC_NEXUS_API_BASE=http://127.0.0.1:8080
```

SSR страниц проектов шлёт cookie на API: удобнее общий домен в проде; локально откройте список проектов из **админки** (`/dashboard/nexus-cloud`).

### 1.4 Воркер сборок (опционально)

```bash
cd nexus-cloud
set REDIS_URL=redis://127.0.0.1:6379
set NEXUS_API_BASE=http://127.0.0.1:8080
set NEXUS_BUILD_WORKER_SECRET=тот_же_что_на_сервере
npm run worker
```

Секрет должен совпадать с `NEXUS_BUILD_WORKER_SECRET` в окружении API (добавьте в `docker-compose` для `api` при необходимости).

### 1.5 Движок для лаунчера локально

1. Соберите библиотеку: `cd engine && cargo build --release`.
2. Либо задайте **`NEXUS_ENGINE_MANIFEST_JSON`** / политику админа с URL zip и **sha256 файла библиотеки** (не zip), либо положите `engine.dll` рядом с клиентом согласно [DEPLOY.md](../DEPLOY.md) (переносимый пакет).
3. Скрипт релиза: `scripts/publish_nexus_engine_release.ps1 -Version 0.1.0`.

### 1.6 Flutter Launcher

```bash
cd client
flutter pub get
flutter run -d windows
```

В профиле URL API: `http://127.0.0.1:8080`.

---

## 2. Продакшен (один VPS)

### 2.1 Домены (пример)

| Домен | Назначение |
|-------|------------|
| `api.example.com` | NEXUS API :8080 за reverse proxy |
| `admin.example.com` | Статика `admin-panel/dist` или прокси |
| `hab.example.com` | Статика `nexus-hab/dist` |
| `cloud.example.com` | Next `nexus-cloud` (или статика + Edge) |

### 2.2 `.env` на сервере (корень)

```env
JWT_SECRET=<openssl rand -base64 48>
ADMIN_OPEN_REGISTRATION=0

CORS_ALLOWED_ORIGINS=https://admin.example.com,https://hab.example.com,https://cloud.example.com,https://api.example.com

SESSION_COOKIE_SECURE=1
NEXUS_ENV=production

NEXUS_BOOTSTRAP_ADMIN_EMAIL=you@example.com

PUBLIC_WEB_BASE_URL=https://hab.example.com

# Stripe / ЮKassa / воркер сборок — по мере нужды
# REDIS_URL в compose override
# NEXUS_BUILD_WORKER_SECRET=...
# STRIPE_SECRET_KEY=...
```

Подставьте свои домены. После первой регистрации и подтверждения почты перезапустите API с `NEXUS_BOOTSTRAP_ADMIN_EMAIL`.

### 2.3 Docker

```bash
cp docker-compose.override.example.yml docker-compose.override.yml
docker compose up -d --build
```

### 2.4 Nginx (фрагмент)

```nginx
# API
server {
    listen 443 ssl http2;
    server_name api.example.com;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    location /ws/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}

# Админка (статика после npm run build; location /api → тот же API)
server {
    listen 443 ssl http2;
    server_name admin.example.com;
    root /var/www/nexus-admin/dist;
    try_files $uri $uri/ /index.html;
    location /api/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_cookie_flags ~ secure samesite=lax;
    }
}
```

Сборка админки: `cd admin-panel && npm ci && npm run build` — в проде `VITE_API_URL` задаётся как `/api` (см. `vite.config.ts`).

### 2.5 Nexus Cloud в проде

Соберите Next: `cd nexus-cloud && npm ci && npm run build && npm start` (или Docker). Обязательно:

```env
NEXT_PUBLIC_NEXUS_API_BASE=https://api.example.com
```

Чтобы cookie сессии работали с `cloud.example.com`, нужен общий parent-domain и выставление cookie с API (сложнее) **или** открывать облачные проекты только из админки. Для полного SSO настройте proxy так, чтобы браузер видел один site (path-based routing: `/cloud` → Next, `/api` → API).

### 2.6 Nexus Hab

`cd nexus-hab && npm ci && npm run build` → раздайте `dist/` как статику на `hab.example.com`. Ссылки на регистрацию могут вести на `https://admin.example.com` или на страницу логина вашего choice.

### 2.7 Манифест движка (Nexus Cloud + лаунчер)

- Залейте zip с `engine.dll` / `.so` / `.dylib` на HTTPS.
- Укажите в **админке** политику движка или задайте `NEXUS_ENGINE_MANIFEST_JSON` / внешний URL манифеста ([`server/src/engine_releases.rs`](../server/src/engine_releases.rs)).
- **`sha256`** в манифесте — от **файла библиотеки**, не от zip ([`scripts/publish_nexus_engine_release.ps1`](../scripts/publish_nexus_engine_release.ps1)).

---

## 3. Чеклист «всё работает»

- [ ] `GET https://api…/health` и `/ready`
- [ ] `GET https://api…/engine/manifest` — версии видны лаунчеру
- [ ] Вход в админку, Ingest Lab, Nexus Cloud, биллинг (если включён)
- [ ] CORS: нет ошибок в консоли браузера с нужных origin
- [ ] Redis: ingest rate limit не пишет warning в логах API
- [ ] `nexus-cloud` worker + секрет: сборки переходят `queued` → `succeeded`
- [ ] Flutter: скачивание/подхват движка по манифесту или локальный dll

---

## 4. Связанные файлы

- [docker-compose.yml](../docker-compose.yml) — API + Postgres
- [docker-compose.full-stack.yml](../docker-compose.full-stack.yml) — демо с ClickHouse, Prometheus, Grafana
- [docker-compose.waypointmetric.example.yml](../docker-compose.waypointmetric.example.yml) — только CORS для WM
- [DEPLOY.md](../DEPLOY.md) — базовый VPS
- [server/.env.example](../server/.env.example) — все переменные API
