# Waypoint / Lynx / Roza — продакшен на VPS

Домены:

| Домен | Продукт | Статика / сервис |
|-------|---------|------------------|
| `waypointclub.ru` | Waypoint Club | `/srv/waypointclub/web` |
| `metrika-waypoint.ru` | Waypoint Metric | `/srv/waypointmetric/dist` |
| `lynx-hub.ru` | Lynx Hub | `/srv/lynx-hub/dist` |
| `lynx-cloud.ru` | Lynx Cloud | Next.js `:3001` |
| `waypointclub.ru/roza` | Roza AI web | `/srv/roza/web/dist` (nginx alias) |

API (Docker):

- `auth-api` — `:8090` (общая авторизация, realms: nexus/lynx, metric, roza)
- `waypoint-api` — `:8080`
- `lynx-api` — `:8082`
- `roza-api` — `:8765`

## Быстрый старт на сервере

1. Скопируйте `repos.env.example` → `/opt/waypoint/repos.env`, заполните `GITHUB_USER` и токен.
2. Скопируйте `smtp.env.example` → `/opt/waypoint/smtp.env`.
3. На **локальной машине** подготовьте репозитории: `bash scripts/prepare-github-repos.sh` (см. комментарии внутри).
4. Залейте репозитории на GitHub (пустые remote — `git push -u origin main`).
5. На VPS: `bash scripts/server-reset-and-deploy.sh`

## Репозитории (рекомендуемые имена)

- `waypoint-auth` — platform/server, только auth-api + postgres
- `waypoint-apis` — waypoint-api + lynx-api (образы из того же Dockerfile)
- `waypoint-club-web` — сборка Club (`VITE_PUBLIC_SITE_MODE=club`)
- `waypoint-metric-web` — сборка Metric
- `lynx-hub` — Vite SPA
- `lynx-cloud` — Next.js
- `roza` — Python API + Dockerfile
- `roza-web` — Vite SPA

Отдельная БД: один контейнер Postgres в стеке `auth`; product API подключаются к ней по `DATABASE_URL` в общей docker-сети `waypoint_net`.

## SMTP

auth-api шлёт коды через webhook `OTP_WEBHOOK_URL`. На сервере поднимается `email-relay` (см. `docker-compose.auth.yml`) — см. `smtp.env.example`.
