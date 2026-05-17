# WaypointMetric

**Помощник для разработчиков сайтов и приложений** по части серверов, баз данных, наблюдаемости и backend-данных. Это **не** продукт про игровой движок **Lynx**: версии ядра, манифесты и студия — в репозитории [`../../Lynx`](../../Lynx).

## Зона ответственности

- **Метрики и логи** с ваших сервисов (ingest по API key, опционально ClickHouse / Prometheus).
- **BaaS**: изолированная схема Postgres на пользователя, SQL (в т.ч. с параметрами `$1…$N`), JSONB REST, realtime, объектное хранилище buckets.
- **Инфраструктурный вектор развития**: подключение узлов, БД, хранилищ, алерты — без привязки к рантайму движка.

## Технически в репозитории

Реализовано бинарником **`Waypoint/api`**, с HTTP-префиксом `/waypointmetric/v1/…` — можно вынести на **отдельный домен** (например `api.waypointmetric.example`) и CORS.

## Публичный API v1

- `GET /waypointmetric/v1/health` — продукт, версия, краткое позиционирование.
- `GET|POST …/waypointmetric/v1/baas/…` — те же возможности, что у `/me/baas/*` (нужен JWT).
- `GET /waypointmetric/v1/storage/public/{owner_user_id}/{bucket}/objects?key=` — без JWT при `public_read` у bucket.

Маршруты Lynx (игровые проекты, облако) в альфе обслуживаются тем же API-хостом; фронты — в [`../../Lynx/cloud`](../../Lynx/cloud). Продуктовая граница: метрики только в `Waypoint/web`.

## Деплой «отдельно от витрины NEXUS»

1. Поднять Docker-образ `Waypoint/api`.
2. В DNS направить поддомен только на этот инстанс или path-based routing в Nginx.
3. Опционально проксировать только `/waypointmetric/`, `/register`, `/login`, health — по политике.

См. `docker-compose.waypointmetric.example.yml` в корне репозитория.
