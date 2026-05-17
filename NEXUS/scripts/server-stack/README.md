# Скрипты для VPS: Lynx (NEXUS compose) + tsput

Каталог: `scripts/server-stack/` (внутри клона **NEXUS**). Пути к репозиториям по умолчанию: `~/nexus`, `~/tsput_profile`. Переопределение:

```bash
cp paths.env.example paths.env
# отредактируйте NEXUS_ROOT / TSPUT_ROOT
```

Экспорт без файла:

```bash
export NEXUS_ROOT=/root/nexus
export TSPUT_ROOT=/root/tsput_profile
```

## Типовой сценарий после «снести всё и запушить новое»

На **своей машине**: `git push` в удалённые репозитории NEXUS и `tsput_profile`.

На **сервере** (под `root` или с `sudo` там, где нужно):

```bash
cd ~/nexus/scripts/server-stack
chmod +x *.sh

# 1) Остановить контейнеры и удалить тома (данные БД и uploads пропадут)
./wipe-docker-all.sh
# или без вопроса: WIPE_CONFIRM=yes ./wipe-docker-all.sh

# 2) Подтянуть код
./git-pull-all.sh
# если pull ругается на локальные правки (compose, scripts/server-stack):
#   ./sync-from-remote.sh

# 3) Заполнить .env в корне NEXUS (JWT_SECRET, CORS, …) — один раз
# 4) Поднять Docker-стеки NEXUS и tsput подряд
./deploy-all-stacks.sh
```

Проверки с сервера:

```bash
curl -sS http://127.0.0.1:8080/health    # Lynx API (NEXUS compose)
curl -sS http://127.0.0.1:8081/health   # tsput (с docker-compose.bind-local-api.yml)
```

## DNS не совпадает с IP ВМ (provision упал)

Скрипт `lynx-vps-provision-public.sh` сравнивает **A-записи** с публичным IPv4 **этого** сервера. Если домены ещё указывают на старый хостинг — сначала поправьте A-записи у регистратора.

Пока DNS не готов, можно поднять **nginx + деплой без TLS**:

```bash
export SKIP_DNS_CHECK=1 SKIP_CERTBOT=1
./lynx-provision-https.sh
```

Потом, когда все `dig +short … A` дают IP этой ВМ, запустите `./lynx-provision-https.sh` снова **без** `SKIP_*` и с реальным `CERTBOT_EMAIL`.

## Публичные домены (Lynx + HTTPS)

Скрипт не удаляет nginx и `/srv/*`. После `wipe-docker-all.sh` конфиг nginx на диске остаётся.

Первичная настройка TLS и выкладка фронтов (admin-panel, hub, Next.js):

```bash
export CERTBOT_EMAIL=you@domain.tld
./lynx-provision-https.sh
```

Или вручную из корня NEXUS: `scripts/lynx-vps-provision-public.sh` (см. `docs/LYNX_DOMAINS_AND_DEPLOY.md`).

Только пересобрать фронты и статику без certbot:

```bash
./nexus-lynx-full-deploy.sh
```

## Отдельные стеки

| Скрипт | Назначение |
|--------|------------|
| `nexus-docker-up.sh` | Только `docker compose` NEXUS (Postgres + API :8080) |
| `tsput-docker-up.sh` | tsput_profile с `docker-compose.bind-local-api.yml` (:8081) |

## Конфликт порта 8081 (tsput не стартует)

Сообщение `Bind for 0.0.0.0:8081 failed: port is already allocated` значит: **другой контейнер уже слушает 8081 на хосте**.

Нужно, чтобы **Rust API** был на **`127.0.0.1:8080`**, а **tsput** — на **8081** (как в `docs/NGINX_PROD_3_SITES_1_APP.conf`).

Проверка:

```bash
grep -n '8081' ~/nexus/docker-compose*.yml
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

В `docker-compose.override.yml` у сервиса `api` / `waypoint_api` задайте `ports: ["8080:8080"]`, затем `cd ~/nexus && docker compose down && docker compose up -d --build`.

Временный обход: поднять tsput на **8082** (`tsput_profile/docker-compose.bind-local-api-8082.yml`) и в nginx у `upstream waypointclub_api` указать `127.0.0.1:8082`.

## Прочее

- Образы Docker после сноса: `WIPE_PRUNE=1 WIPE_CONFIRM=yes ./wipe-docker-all.sh`
- Подъём с `git pull`: `PULL_FIRST=1 ./deploy-all-stacks.sh`

### Учебный стенд «Большие данные» снят с репозитория

Каталог `labs/bigdata-distributed-course` и скрипты `bigdata-labs-*.sh` / `demo-bigdata-lab.sh` **удалены**. `deploy-all-stacks.sh` поднимает только **NEXUS compose** и **tsput**.

**На VPS**, если раньше запускали тот compose, после `git pull` путь к проекту пропадёт, но контейнеры могли остаться. Проверьте и остановите вручную:

```bash
docker ps -a --format 'table {{.Names}}\t{{.Ports}}'
# типичные имена: *api*, *db*, *rabbitmq*, *minio*, *reports* из старого проекта лаб
docker stop ИМЯ… && docker rm ИМЯ…
```

Либо одним проходом снести только свои стеки и поднять заново: `WIPE_CONFIRM=yes ./wipe-docker-all.sh`, затем `./deploy-all-stacks.sh` (осторожно: **сотрётся БД NEXUS и tsput**).
