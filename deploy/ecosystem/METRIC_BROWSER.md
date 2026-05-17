# Waypoint Metric — что работает в браузере

## Работает (при запущенных auth-api :8090 и waypoint-api :8080)

| Раздел | Маршрут | API |
|--------|---------|-----|
| Витрина | `metrika-waypoint.ru` / `VITE_PUBLIC_SITE_MODE=metric` | — |
| Вход / регистрация | `/login`, `/register` | auth-api `/auth` |
| Обзор | `/dashboard/overview` | `GET /me/metrics/summary`, `GET /me/system-metrics` |
| Ingest Lab | `/dashboard/ingest-lab/*` | metrics, simulate, keys |
| Подключение | `/dashboard/connect` | self-test, export, replay |
| BaaS | `/dashboard/baas/*` | `/me/baas/*` |
| Документация ingest | `/platform` | curl-примеры |

Сборка продакшена: `waypoint-metric-web` с `.env.production`: `VITE_PUBLIC_SITE_MODE=metric`.

## Реальная запись из браузера (новое)

- **Ingest Lab → Запись в облако** (`/dashboard/ingest-lab/send`) — `POST /me/ingest`, данные в БД.
- **Симуляция** — кнопка «Записать в облако» на той же странице.
- **Журнал логов** — `/dashboard/ingest-lab/logs` → `GET /me/logs`.
- **Продакшен-клиенты** — по-прежнему `POST /api/waypoint/ingest` + `X-API-Key` (`wpk_…`).

## Ограничения

- **Графики CPU/RAM** — нужен `agent_api_key` в workspace или fallback на сервере.
- **Логи ingest** — `GET /me/logs` на сервере есть, UI в Metric не подключён.
- **localhost** без `.env` — по умолчанию Club, не Metric; для dev: `VITE_PUBLIC_SITE_MODE=metric`.

## Проверка локально

```powershell
docker compose -f d:\PO\deploy\ecosystem\docker-compose.auth.yml --env-file d:\PO\deploy\ecosystem\smtp.env up -d
docker compose -f d:\PO\deploy\ecosystem\docker-compose.apis.yml --env-file d:\PO\deploy\ecosystem\smtp.env up -d
cd d:\PO\Waypoint\web
npm run dev:metric
```

После входа: Ingest Lab → **Отправить демо-набор** → Сводка / Таблица метрик / Журнал логов.
