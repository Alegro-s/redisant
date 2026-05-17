# NEXUS: деплой на арендованный сервер (5 минут до первой ценности)

Цель: поднять API, применить миграции, открыть HTTPS через reverse proxy, проверить health и отправить тестовый ingest.

## 1. На сервере: PostgreSQL

Создайте БД и пользователя, задайте `DATABASE_URL` (см. `server/.env.example`). Если поднимаете стек через **Docker Compose** (следующий раздел), отдельно ставить Postgres не нужно.

## 2. Docker Compose (API + Postgres на VPS)

В корне репозитория есть [`docker-compose.yml`](docker-compose.yml): контейнер **PostgreSQL** и сборка **API** из [`server/Dockerfile`](server/Dockerfile). Миграции выполняются при старте бинарника, как и при обычном `cargo run`.

На сервере (Linux с установленным Docker и Compose v2):

1. Склонируйте репозиторий или скопируйте на машину папки `server/` и файлы `docker-compose.yml`, `server/Dockerfile`, `server/.dockerignore`.
2. **Локально:** `docker compose up -d --build` — в compose подставляется dev-`JWT_SECRET` (для публичного VPS замените).
3. **Первый доступ к консоли admin/nexus:** `POST /admin/register` в текущей сборке отключён. Создайте обычного пользователя через **Регистрация**, затем либо задайте в `.env` **`NEXUS_BOOTSTRAP_ADMIN_EMAIL`** (email этого пользователя) и перезапустите API, либо повысьте роль SQL — пошагово в **[docs/ADMIN_CONSOLE_KEYS.md](docs/ADMIN_CONSOLE_KEYS.md)**. После появления **nexus** ключи **admin** для команды выпускаются в разделе **Admin keys**.

```bash
export JWT_SECRET="$(openssl rand -base64 32)"
export CORS_ALLOWED_ORIGINS="http://ВАШ_IP:8080,http://ВАШ_IP:5173"
docker compose up -d --build
```

4. Откройте порт **8080** в фаерволе облака/VPS (`ufw allow 8080` и правила у провайдера).
5. Проверка: `curl -sS http://127.0.0.1:8080/health` на сервере; с вашего ПК — `http://ВАШ_IP:8080/health`.

Во **Flutter** в профиле укажите `http://ВАШ_IP:8080` (CORS на мобильном/десктопе не мешает).

Пароль БД в compose по умолчанию `nexus` / пользователь `nexus` — для продакшена смените в `docker-compose.yml` и пересоздайте volume или задайте свои значения до первого запуска.

Обновление после `git pull`:

```bash
docker compose up -d --build
```

### Скрипты (VPS + локальный ПК)

| Где | Файл | Назначение |
|-----|------|------------|
| Сервер (самый первый заход) | `scripts/vps-change-root-password.sh` | Смена пароля **root** (интерактивно, ≥12 символов) |
| Сервер (до Docker) | `scripts/vps-phase1-server-init.sh` | `apt upgrade`, базовые пакеты, **ufw** 22+8080, опционально пользователь `nexus` |
| Сервер (первый раз) | `scripts/vps-bootstrap.sh` | Ubuntu: Docker + Compose + Git (`sudo bash scripts/vps-bootstrap.sh`) |
| Сервер (сброс БД в Docker + занятый деплой) | `scripts/vps-reset-and-up.sh` | `down -v` (тома Postgres и uploads), затем `up -d --build`; см. `local` / `cloud` в шапке скрипта |
| Сервер (сброс Docker-томов + git как на GitHub, без конфликта pull) | `scripts/vps-server-fresh-from-git.sh` | Бэкап `.env`, `down -v`, `git reset --hard origin/main`, `clean -fd`, `up -d --build`; режим `reclone` — см. шапку скрипта |
| Сервер (каждый выклад) | `scripts/vps-deploy.sh` | `git pull` и `docker compose up -d --build` из корня клона |
| Сервер (полная пересборка) | `scripts/vps-build-all.sh` | `git pull`, `docker compose`, сборка `admin-panel` в `dist/`; опции `SKIP_*`, `BUILD_FLUTTER=1` — см. заголовок скрипта |
| Сервер | `scripts/vps-git-remote-ssh.sh` | Перевести `origin` на SSH для private repo + Deploy key |
| Сервер / локально | `scripts/vps-minimal-clone.sh` | Только `server/` + compose-файлы (без Flutter) |
| Windows (у себя) | `scripts/local-remote-deploy.ps1` | SSH на сервер: pull + compose без ручного входа |
| Локально | `scripts/start-server-docker.ps1` / `.sh` | Только Docker на этой машине |
| Termius / обрыв длинных команд | [`scripts/termius-one-liners.txt`](scripts/termius-one-liners.txt) | Мелкие блоки: `git pull`, `compose`, `curl /health` |

На сервере после клона: `cp .env.example .env`, задать `JWT_SECRET` и `CORS_ALLOWED_ORIGINS` с вашим `http://IP:8080` (и портами админки, если нужен браузер).

## 3. Сборка и переменные (без Docker)

```bash
cd server
cp .env.example .env
# Отредактируйте .env: DATABASE_URL, JWT_SECRET (≥32 символов), NEXUS_ENV=production,
# BIND_ADDRESS=0.0.0.0:8080, CORS_ALLOWED_ORIGINS=ваши домены
```

### Без домена (только IP)

Укажите в `CORS_ALLOWED_ORIGINS` явные origin клиентов, с которых идут браузерные запросы (протокол + IP + порт), через запятую, например:

`http://203.0.113.10:8080,http://203.0.113.10:3000`

- первый — если открываете веб-клиент с того же хоста;
- второй — порт **Vite** для `admin-panel` в этом репозитории (`npm run dev`, см. `admin-panel/vite.config.ts`).

Во **Flutter** (десктоп/мобильный) CORS не действует: в приложении в **Профиль → URL сервера** задайте `http://ВАШ_IP:8080`.

Миграции применяются **автоматически** при старте бинарника (`sqlx migrate` встроен).

```bash
cargo build --release
./target/release/server
```

Проверка:

- `GET /health` — процесс жив (для балансировщика / uptime).
- `GET /ready` — доступна БД (для Kubernetes / оркестраторов).

## 4. HTTPS (рекомендуется)

Не обязательно вшивать TLS в Rust: поставьте **Caddy** или **Nginx** перед приложением.

Пример Caddy (`/etc/caddy/Caddyfile`):

```text
api.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

Тогда в `CORS_ALLOWED_ORIGINS` укажите `https://api.example.com` и origin вашего фронта/админки.

### WebSocket (совместное редактирование сцен в клиенте NEXUS)

Путь: `/ws/projects/{uuid}/scenes/{scene_id}`. Прокси должен пропускать **Upgrade: websocket**. Пример фрагмента Nginx:

```nginx
location /ws/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 3600s;
}
```

Клиент может передавать JWT в query: `?access_token=...` (удобно для `WebSocketChannel`), либо заголовком `Authorization: Bearer ...`.

### Локальный агент БД (integrations/agent)

Выдайте TLS сертификат на публичный URL агента (тот же Caddy/Nginx), ограничьте доступ по сети. Секрет — `NEXUS_AGENT_KEY`, совпадающий с `agent_api_key` в workspace; см. `docs/AGENT_PROTOCOL.md`.

- **Образ:** `docker build -f integrations/agent/Dockerfile integrations/agent` (тег для своего registry, не Docker Hub по умолчанию).
- **Compose (TLS только снаружи):** агент слушает `127.0.0.1:9847`, наружу — HTTPS через nginx с `proxy_pass` на `http://127.0.0.1:9847`. См. [`docker-compose.agent.yml`](docker-compose.agent.yml).
- **Kubernetes:** минимальный chart в [`helm/nexus-agent/`](helm/nexus-agent/) — Ingress с TLS, секреты `DATABASE_URL` и ключа вручную.
- **Роли Postgres:** шаблон только для чтения — [`docs/sql/nexus_agent_readonly.sql`](docs/sql/nexus_agent_readonly.sql) (применять на стороне БД клиента).

Пример фрагмента nginx (только HTTPS, HTTP редирект на 443):

```nginx
server {
    listen 443 ssl http2;
    server_name agent.example.com;
    ssl_certificate     /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:9847;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 5. Сценарий «ценность за 5 минут»

1. Зарегистрируйте пользователя: `POST /register` (как в клиенте или curl).
2. Скопируйте `ingest_api_key` из ответа.
3. Отправьте метрики:

```bash
curl -sS -X POST "https://api.example.com/api/waypoint/ingest" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ВАШ_КЛЮЧ" \
  -d '{"metrics":[{"name":"demo.cpu","value":1.0}],"logs":[{"level":"info","message":"hello"}]}'
```

4. В приложении откройте профиль — ключ и URL ingest; `GET /me/metrics` с JWT покажет сохранённые точки.

## 6. Админка и опасные функции

- В **production** произвольный SQL (`/admin/db/query`) **отключён**, пока не выставите `ADMIN_ALLOW_RAW_SQL=1`.
- Запросы на изменение данных (`UPDATE`, `DELETE`, …) дополнительно требуют `ADMIN_ALLOW_SQL_WRITE=1`.

## 7. Бэкапы БД

См. `scripts/backup-postgres.sh` (запуск по cron).

## 8. Тесты

```bash
cd server && cargo test
```

Покрыты политика admin-SQL и базовые проверки; полный e2e — с поднятым Postgres и `DATABASE_URL`.

## 9. Логи и алерты

- `LOG_JSON=1` — однострочный JSON в stdout (удобно для агрегаторов).
- `ALERT_WEBHOOK_URL` — POST с телом `{"text":"..."}` при критичных логах ingest и при отправке VK-алерта (дублирование для Slack и т.п.).

## 10. Клиент Flutter: сборки под магазины (2D / FFI)

Полноценный «конвейер как у Unity» — это отдельный CI (подписи, track internal/beta, метаданные). Для NEXUS из коробки:

- **Android (Play):** в каталоге `client/` задайте `key.properties` и `upload-keystore.jks`, затем `flutter build appbundle`. В манифесте/gradle уже типична конфигурация из шаблона Flutter; проверьте `minSdk` под нативный FFI (обычно ≥21).
- **iOS (App Store):** `flutter build ipa` после настройки Xcode signing, team id и capabilities. Для **Rust engine** как `cdylib` на iOS потребуется отдельная сборка под device/simulator и встраивание в Runner (сейчас движок ориентирован на десктоп; мобильный play можно оставить на веб/демо-слое до полной линковки).
- **Windows (Store MSIX):** `flutter build windows` + упаковка через `msix_config.yaml` / Partner Center — как в стандартных гайдах Flutter.

В редакторе доступен пункт **«Сборка папки (данные + engine)»** — это **переносимый пакет `game_data` + `bin/engine.dll`**, а не замена store pipeline.
