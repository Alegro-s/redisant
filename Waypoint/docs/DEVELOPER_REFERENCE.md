# Справочник разработчика Waypoint (веб-консоль)

Сжатый ориентир для тех, кто вносит изменения в монорепозиторий: куда смотреть по темам и в каком порядке читать документы при онбординге.

---

## Быстрые ссылки

| Тема | Документ |
|------|----------|
| **Прозрачная работа + поток консоли** (лендинг → тариф → вход → онбординг → кабинет) | [TRANSPARENCY_AND_CONSOLE_FLOW.md](TRANSPARENCY_AND_CONSOLE_FLOW.md) |
| Деплой, CORS, VPS | [DEPLOY.md](../DEPLOY.md) |
| Прод-риски, чеклист | [OPERATIONS.md](OPERATIONS.md) |
| Веб-консоль метрик, роли, API-URL | [WAYPOINT_METRICS.md](WAYPOINT_METRICS.md) |
| Ограничения по компонентам | [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) |
| OpenAPI Waypoint (ingest, auth) | [openapi-waypoint-metric.yaml](openapi-waypoint-metric.yaml) |
| Движок и автор игр | [GAME_AUTHOR.md](GAME_AUTHOR.md) |
| DB Agent | [AGENT_PROTOCOL.md](AGENT_PROTOCOL.md) |
| Полный индекс docs | [README.md](README.md) |

---

## Код, связанный с потоком консоли

| Что | Путь |
|-----|------|
| Лендинг, тарифы, аккордеон «прозрачная работа» | `web/src/pages/LandingPage.tsx` |
| План с лендинга (sessionStorage) | `web/src/utils/preferredPlan.ts` |
| Онбординг (аренда / свой сервер) | `web/src/pages/onboarding/Onboarding.tsx` |
| Состояние workspace, `onboarding_completed` | `web/src/app/contexts/WorkspaceContext.tsx` |
| Защита маршрутов, «нужен сервер» | `web/src/components/PrivateRoute.tsx` |
| Маршруты SPA | `web/src/App.tsx` |

---

## Онбординг в репозитории (документы)

1. [README.md](../README.md) — состав монорепозитория.
2. [docs/README.md](README.md) — карта всей документации и практические маршруты.
3. [TRANSPARENCY_AND_CONSOLE_FLOW.md](TRANSPARENCY_AND_CONSOLE_FLOW.md) — прозрачность и UX-поток консоли.
4. [DEPLOY.md](../DEPLOY.md) + [OPERATIONS.md](OPERATIONS.md) — если трогаете прод или сессии.

После значимых изменений в RBAC, онбординге или лендинге обновляйте **TRANSPARENCY_AND_CONSOLE_FLOW.md** в том же PR.
