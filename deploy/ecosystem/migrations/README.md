# Миграции БД

Схема PostgreSQL живёт в `platform/server/migrations/`. Применяется **только** при старте `auth-api` (`RUN_MIGRATIONS=1`).

## Локально (Docker)

```powershell
cd d:\PO\deploy\ecosystem
copy smtp.env.example smtp.env
# JWT_SECRET и POSTGRES_PASSWORD в smtp.env или .env

docker compose -f docker-compose.auth.yml up -d --build db
# дождаться healthy, затем:
docker compose -f docker-compose.auth.yml up -d --build auth-api
docker compose -f docker-compose.auth.yml logs auth-api | Select-String migrations
```

## Отдельный прогон (без поднятия API)

```powershell
docker compose -f docker-compose.auth.yml run --rm auth-api
```

## API после миграции

```powershell
docker compose -f docker-compose.apis.yml --env-file smtp.env up -d --build
```

`waypoint-api` (:8080) — Metric, ingest, BaaS.  
`lynx-api` (:8082) — Lynx Cloud / Hub backend.  
`auth-api` (:8090) — login, register, realms (nexus, metric, roza).
