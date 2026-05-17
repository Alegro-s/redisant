# Документация NEXUS

Единая точка входа в материалы монорепозитория. Исходный код и краткий обзор репозитория — в корневом [README.md](../README.md).

---

## Быстрая ориентация

| Слой | Каталог | Зачем открывать |
|------|---------|-----------------|
| HTTP API + WebSocket | `server/` | Аутентификация, проекты, Waypoint (метрики, ingest), биллинг, админ-эндпоинты |
| Веб-консоль «Метрика» | `admin-panel/` | Операторская панель: дашборды, метрики, пользователи (см. [WAYPOINT_METRICS.md](WAYPOINT_METRICS.md)) |
| Игровой клиент | `client/` | Редактор и рантайм на Flutter |
| Движок | `engine/` | Сцена, Lua, физика; FFI в клиент |
| Отправка метрик из кода | `WaypointMetrics/` | Python-клиент для ingest в API |
| Агент БД / боты | `integrations/agent/`, `vk-bot/` | Read-only SQL-агент, ВКонтакте |

---

## Карта документов

### Развёртывание и эксплуатация

| Документ | Кому | Содержание |
|----------|------|------------|
| [DEPLOY.md](../DEPLOY.md) | DevOps | Compose, VPS, HTTPS, CORS, скрипты, переменные окружения |
| [OPERATIONS.md](OPERATIONS.md) | DevOps, ответственные за прод | Типичные ловушки при выкладке: CORS и cookie, миграции, RBAC, масштаб, CI |
| [`.env.example`](../.env.example) | Все | Compose и сессия веб-консоли |
| [`server/.env.example`](../server/.env.example) | Backend | Полный набор переменных API |

### Веб-консоль и метрики Waypoint

| Документ | Кому | Содержание |
|----------|------|------------|
| [WAYPOINT_METRICS.md](WAYPOINT_METRICS.md) | Интеграторы, админы консоли | Бренд, вход и cookie, роли, разделы UI, Python, OpenAPI |
| [ADMIN_CONSOLE_KEYS.md](ADMIN_CONSOLE_KEYS.md) | DevOps, владелец инстанса | Первый **nexus**, ключи admin/nexus на 60 символов, активация после `git`/деплоя |
| [openapi-waypoint-metric.yaml](openapi-waypoint-metric.yaml) | Интеграторы | Контракт REST для регистрации, ingest, чтения своих данных |

### Авторы игр и движок

| Документ | Кому | Содержание |
|----------|------|------------|
| [GAME_AUTHOR.md](GAME_AUTHOR.md) | Авторы контента | Возможности движка, форматы, ограничения редактора |

### Платформа, агент, ограничения

| Документ | Кому | Содержание |
|----------|------|------------|
| [DEVELOPER_HANDBOOK.md](DEVELOPER_HANDBOOK.md) | Разработчики репозитория | Сценарий главная → тариф → вход → онбординг → кабинет; прозрачная работа (риски прода); ссылки на детали |
| [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) | Разработчики платформы | Известные границы по компонентам и рекомендации |
| [AGENT_PROTOCOL.md](AGENT_PROTOCOL.md) | Интеграторы | Протокол NEXUS DB Agent |
| [sql/nexus_agent_readonly.sql](sql/nexus_agent_readonly.sql) | Админы БД | Пример политики прав для агента |

---

## Маршруты онбординга (практика)

0. **Сценарий пользователя и риски прода:** [DEVELOPER_HANDBOOK.md](DEVELOPER_HANDBOOK.md).
1. **Поднять API и БД:** [DEPLOY.md](../DEPLOY.md) → задать `JWT_SECRET`, `DATABASE_URL`, `CORS_ALLOWED_ORIGINS`.
2. **Подключить веб-консоль:** [WAYPOINT_METRICS.md](WAYPOINT_METRICS.md) → `VITE_API_URL`, origin в CORS, cookie за HTTPS при проде.
3. **Отправить метрики из сервиса:** [WAYPOINT_METRICS.md](WAYPOINT_METRICS.md) + [openapi-waypoint-metric.yaml](openapi-waypoint-metric.yaml).
4. **Работать с клиентом/движком:** [GAME_AUTHOR.md](GAME_AUTHOR.md); риски — [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).
5. **Перед прод-релизом:** [OPERATIONS.md](OPERATIONS.md) и чеклист в [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).

---

## Обратная связь по документации

Неточности и пробелы лучше фиксировать в issue-трекере с указанием файла и сценария (локально / Docker / VPS). После значимых изменений в API или RBAC обновляйте [openapi-waypoint-metric.yaml](openapi-waypoint-metric.yaml), [WAYPOINT_METRICS.md](WAYPOINT_METRICS.md) и при необходимости [OPERATIONS.md](OPERATIONS.md).
