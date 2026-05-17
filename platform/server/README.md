# PO Platform Server

Три отдельных HTTP-процесса из одного кода, разные маршруты:

| Бинарник | `PO_SERVICE` | Порт | Назначение |
|----------|--------------|------|------------|
| `auth-api` | auth | 8090 | Регистрация, вход, профиль, `/auth/introspect`, VK (заготовка) |
| `waypoint-api` | waypoint | 8080 | Метрики, ingest, BaaS, WaypointMetric |
| `lynx-api` | lynx | 8082 | Проекты, движок, Lynx Cloud, чат, WebSocket |

Общие: **PostgreSQL**, **`JWT_SECRET`**, cookie **`waypoint_session`** (legacy: `nexus_session`).

## Сборка

```bash
cargo build --release --bin auth-api --bin waypoint-api --bin lynx-api
```

## Docker (все три)

```bash
cd D:/PO/deploy
docker compose -f docker-compose.split.yml up -d --build
```
