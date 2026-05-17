# Протокол NEXUS DB Agent

Агент — это HTTP-сервис в сети пользователя с доступом к его PostgreSQL. Облако NEXUS не подключается к БД напрямую: пользователь указывает в workspace **URL агента** (`connection_url`, например `https://agent.example.com`) и **общий секрет** (`agent_api_key`), совпадающий с переменной окружения агента `NEXUS_AGENT_KEY`.

## Эндпоинты агента

| Метод | Путь | Заголовки | Тело | Ответ |
|--------|------|-----------|------|--------|
| `POST` | `/v1/sql` | `X-Agent-Key: <secret>` | `{"query":"SELECT ..."}` | `{"columns":[...],"rows":[{...}, ...]}` |
| `GET` | `/v1/schema` | `X-Agent-Key` | — | JSON-снимок: таблицы `schema.name` → `{ schema, name, columns[], foreign_keys[] }`; FK из `information_schema` (цель `ref_table` в формате `schema.table`) |
| `GET` | `/health` | — | — | `ok` |

Правила SQL на агенте: только один оператор без `;` внутри; после удаления комментариев строка должна начинаться с `SELECT` или `WITH` (read-only).

## Облако NEXUS

- **Прокси SQL:** при `POST /me/db/query` с JWT, если у пользователя заданы `connection_url` и `agent_api_key`, сервер вызывает `{connection_url}/v1/sql`, передавая тот же SQL и заголовок `X-Agent-Key` из workspace. Ответ агента (`columns` + `rows`) возвращается клиенту как есть.
- **Кэш схемы для диаграмм:** `POST /integrations/agent/heartbeat` с `X-Agent-Key` и телом `{"schema": {...}, "metrics": null}`. Сервер находит пользователя по ключу и сохраняет `agent_schema_snapshot`, `agent_last_seen`. Клиент читает `GET /me/agent/schema` (JWT).

## Референсная реализация

Каталог `integrations/agent` — минимальный бинарник на Rust (Axum + sqlx).

Переменные окружения:

| Переменная | Назначение |
|------------|------------|
| `DATABASE_URL` | Строка подключения PostgreSQL |
| `NEXUS_AGENT_KEY` | Должен совпадать с `agent_api_key` в workspace |
| `NEXUS_AGENT_BIND` | Адрес прослушивания (по умолчанию `0.0.0.0:9847`) |
| `NEXUS_HEARTBEAT_URL` | Полный URL, например `https://api.your-nexus.com/integrations/agent/heartbeat` (опционально) |
| `NEXUS_HEARTBEAT_INTERVAL_SECS` | Интервал отправки схемы (по умолчанию `120`) |

Сборка и запуск:

```bash
cd integrations/agent
cargo run --release
```

За TLS и публикацию в интернет отвечает reverse proxy (nginx, Caddy и т.д.).

## Безопасность

- Ключ никогда не логировать.
- Агент только во внутренней сети или за VPN; наружу — только HTTPS.
- Рассмотреть IP allowlist и отдельную роль БД с правами только на `SELECT`.
- Шаблон роли только чтение для строки `DATABASE_URL` агента: [`docs/sql/nexus_agent_readonly.sql`](sql/nexus_agent_readonly.sql) (выполнять на стороне Postgres пользователя).

## Совместные сцены (WebSocket)

Подключение: `GET /ws/projects/{project_id}/scenes/{scene_id}` с JWT либо в заголовке `Authorization: Bearer …`, либо в query **`?access_token=…`** (удобно для браузера и Flutter `WebSocketChannel`). Доступ только при праве **записи** в проект (`user_can_write_project`).

Текстовые кадры пересылаются подписчикам как есть (JSON от клиента, например `type: nexus_scene_sync` после успешного `PUT` сцены). Сохранение в `project_scenes` по-прежнему через REST; канал — для live-обновления у других редакторов.
