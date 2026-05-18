# Миграции БД (auth / waypoint / lynx)

Миграции лежат в `platform/server/migrations/`. Применяются **только** контейнером `auth-api` при `RUN_MIGRATIONS=1`.

## Порядок

1. Поднять Postgres (`docker-compose.auth.yml`).
2. Запустить `auth-api` — sqlx migrate.
3. Поднять `waypoint-api` и `lynx-api` без повторного migrate.

## Новые миграции

- `20260517120000_desktop_devices.sql` — устройства Desktop, pairing, refresh tokens, `api_keys.scope`.

## Откат

Ручной откат не автоматизирован. Для dev: пересоздать volume Postgres.

## Продакшен

На VPS: `deploy/ecosystem/scripts/server-02-clone-github-redik.sh` пересобирает API после `git pull`.
