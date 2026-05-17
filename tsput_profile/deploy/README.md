# Деплой Docker и MAX Mini App

## Что поднимается

- **api** — FastAPI (в контейнере `:8080`; на хост пробрасывается через `docker-compose.publish-8080.yml` или `docker-compose.bind-local-api.yml`)
- **db** — PostgreSQL 16 (данные API пока в коде; БД зарезервирована под уведомления и кэш)
- **nginx** (профиль `web`) — отдаёт Flutter Web и проксирует `/api` на backend

## Быстрый старт на сервере

Скрипты для **сервера** (скопируй в `~/tsput_profile/scripts/` после `git pull` или вместе с репозиторием):

- **`scripts/server_remove_tula_travel.sh`** — остановить compose в `~/tula-travel` (если есть) и удалить каталог.
- **`scripts/server_run_tsput_profile.sh`** — `docker compose ... up -d --build` для ТГПУ профиля и проверка `/health`.

На сервере: `chmod +x scripts/server_*.sh`

1. Установи Docker и Docker Compose.
2. Склонируй репозиторий на сервер (или скопируй файлы).
3. В корне проекта:

```bash
docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build
```

Проверка: `curl http://localhost:8080/health`

Логин API (демо): `student@university.ru` / `password123`

## Миграция на VPS (замена старого проекта, пример IP `72.56.244.26`)

Закрытые у хостинга порты почты/RDP (25, 465, 587, 2525, 3389, …) **не мешают**: API и приложение используют **80/443** и/или **8080**.

**1. Остановить и убрать старый проект** (если был в Docker):

```bash
cd ~/TulaTravelv1.2   # или где лежал compose
docker compose down -v   # -v удалит тома БД старого проекта; без -v тома останутся
cd ~
rm -rf TulaTravelv1.2   # только если бэкап не нужен
```

**2. Поставить этот проект**

```bash
cd ~
git clone <URL_вашего_репозитория> tsput_profile
cd tsput_profile
docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build
```

Проверка снаружи (подставь свой IP):

```bash
curl http://72.56.244.26:8080/health
```

**3. Flutter / мобильное приложение**

- Только API на **8080** (без nginx-профиля `web`):

```text
INTEGRATION_BASE_URL=http://72.56.244.26:8080
```

- Если поднят **nginx** на **80** с прокси `/api` (профиль `web`, см. ниже), база для клиента:

```text
INTEGRATION_BASE_URL=http://72.56.244.26
```

(без порта и без `/` в конце; пути `/api/...` добавляет само приложение.)

**4. Безопасность**

- В проде **не открывайте PostgreSQL наружу**: в `docker-compose.yml` у сервиса `db` уберите проброс `ports: "5432:5432"` или ограничьте файрволом только `127.0.0.1`.
- Для продакшена лучше **HTTPS** (certbot / Caddy) и домен; тогда `INTEGRATION_BASE_URL=https://ваш-домен.ru`.

## Залить проект на сервер (ты делаешь у себя)

Готовый скрипт (удаляет на сервере файлы, которых уже нет в локальной копии, **кроме** `.env` и `build/`):

```bash
chmod +x scripts/deploy_server.example.sh
./scripts/deploy_server.example.sh USER@HOST ~/tsput_profile
```

Перед первым запуском на сервере положи свой `.env` рядом с `docker-compose.yml` (если нужны `MOODLE_*` и т.д.) — он **не** перезаписывается `rsync`.

Пример с `scp` (замени `USER` и `HOST`):

```bash
# из каталога с проектом
scp -r . USER@HOST:~/tsput_profile
ssh USER@HOST "cd ~/tsput_profile && docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build"
```

Или через git: `git clone` на сервере и `docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build`.

## Flutter: онлайн к твоему API

Собери приложение с базовым URL сервера:

```bash
flutter run --dart-define=INTEGRATION_BASE_URL=http://YOUR_SERVER_IP:8080
```

Или для релиза:

```bash
flutter build apk --release --dart-define=INTEGRATION_BASE_URL=https://your-domain.ru
```

## MAX Mini App

В MAX мини-приложения открываются как **HTTPS URL** в WebView (документация: [dev.max.ru](https://dev.max.ru/docs/webapps/bridge)).

1. Собери Flutter Web с **одним** origin для API и статики (через nginx ниже):

```bash
flutter build web --release --base-href / --dart-define=INTEGRATION_BASE_URL=
```

Для продакшена укажи публичный HTTPS-адрес **без порта** (nginx на 443):

```bash
flutter build web --release --base-href / --dart-define=INTEGRATION_BASE_URL=https://your-domain.ru
```

2. Скопируй `build/web/*` на сервер в каталог `build/web` в корне репозитория (как ожидает `docker-compose`).  
   Если каталога ещё нет: `mkdir -p build/web && cp deploy/web_stub/index.html build/web/index.html`

3. Запусти с профилем `web`:

```bash
docker compose --profile web up -d --build
```

4. В кабинете MAX укажи URL приложения: `https://your-domain.ru/` (обязательно HTTPS).

Скрипты для Windows/Linux: `scripts/build_web_for_max.ps1`, `scripts/build_web_for_max.sh`.

## TLS (HTTPS)

Для MAX нужен валидный сертификат. Варианты: Caddy, Traefik, certbot + nginx — настрой на своём сервере отдельно; в этом репозитории только HTTP-конфиг nginx для примера.

## Рядом с NEXUS / Lynx (один VPS, домен waypointclub.ru)

Чтобы не занимать порт **8080** (там Rust API NEXUS), поднимайте только `api` + `db` с привязкой FastAPI к **127.0.0.1:8081**:

```bash
docker compose -f docker-compose.yml -f docker-compose.bind-local-api.yml up -d --build
```

Системный nginx (шаблон в репозитории NEXUS: `docs/NGINX_PROD_3_SITES_1_APP.conf`) отдаёт статику из **`/srv/waypointclub/web`** и проксирует `/api/` на `8081`. Соберите Flutter Web и скопируйте `build/web/*` на сервер:

```bash
flutter build web --release --base-href / --dart-define=INTEGRATION_BASE_URL=https://waypointclub.ru
sudo mkdir -p /srv/waypointclub/web
sudo rsync -a build/web/ /srv/waypointclub/web/
```

TLS и ACME — вместе с остальными доменами Lynx (`scripts/lynx-vps-provision-public.sh` в NEXUS уже включает `waypointclub.ru`).
