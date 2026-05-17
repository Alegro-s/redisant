# Waypoint

**Waypoint** — продукт наблюдаемости и backend-данных для сайтов и приложений: метрики, логи, ingest, BaaS, алерты, веб-консоль оператора.

Не путать с **Lynx** (игровой движок и студия) — см. [`../Lynx/README.md`](../Lynx/README.md).

## Состав

| Каталог | Назначение |
|---------|------------|
| `api/` | Исходники **waypoint-api** (синхрон с `platform/server`) |
| `../platform/server` | Три бинарника: **auth-api**, **waypoint-api**, **lynx-api** |
| `web/` | SPA веб-консоли (Vite + React + MUI), лендинг, Ingest Lab, дашборды |
| `sdk-python/` | Python-клиент отправки метрик и логов |
| `vk-bot/` | Интеграция ВКонтакте |
| `infra/` | Prometheus, Grafana, ClickHouse (опционально) |
| `docs/` | Операции, OpenAPI, ключи admin |

## Локальный запуск (три API)

```powershell
cd D:\PO\deploy
copy docker-compose.split.yml docker-compose.override.yml  # опционально
docker compose -f docker-compose.split.yml up -d --build

# auth :8090  waypoint :8080  lynx :8082
curl http://127.0.0.1:8090/health
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8082/health

cd D:\PO\Waypoint\web
npm ci
npm run dev
```

Веб: `http://127.0.0.1:3000`. Логин идёт на **auth-api** (`VITE_AUTH_URL`, см. `web/.env.example`); метрики — на **waypoint-api**.

## Десктоп

Приложение **Waypoint** (Tauri) для Windows — репозиторий `d:\player\desktop`. Сборка: `npm run tauri build`. Это **рабочий стол на ПК** (CRM, план, облако, чат), а не замена `web/` для ingest.

## Документация

- [docs/WAYPOINT_METRICS.md](docs/WAYPOINT_METRICS.md) — роли, сессия, ingest
- [docs/product/README.md](docs/product/README.md) — границы WaypointMetric vs Lynx
- [DEPLOY.md](DEPLOY.md) — VPS, Docker, nginx
- [docs/openapi-waypoint-metric.yaml](docs/openapi-waypoint-metric.yaml) — контракт API

## Связь с Lynx

- **auth-api** — общий вход (email/пароль, позже VK OAuth).
- **waypoint-api** — только метрики и BaaS.
- **lynx-api** — проекты, движок, Cloud, чат (`../Lynx/api`).

Один `JWT_SECRET` и cookie `waypoint_session` на всех сервисах.
