# Lynx Cloud (Next.js, каталог `nexus-cloud/`)

Панель разработчика: проекты (прокси к API), ядро, сборки; воркер очереди для облачных сборок.

## Запуск

```bash
npm install
# Redis: docker compose -f ../docker-compose.nexus-cloud.yml up -d
export NEXT_PUBLIC_LYNX_API_BASE=http://127.0.0.1:8080
export NEXT_PUBLIC_WAYPOINT_CONSOLE_URL=http://127.0.0.1:5173
export NEXT_PUBLIC_LYNX_HUB_URL=http://127.0.0.1:5175
npm run dev
```

Воркер очереди (заглушка):

```bash
REDIS_URL=redis://127.0.0.1:6379 npm run worker
```

## Переменные

| Переменная | Назначение |
|------------|------------|
| `NEXT_PUBLIC_LYNX_API_BASE` | URL API Lynx/WaypointMetric (проекты `/me/lynx-cloud/projects`) |
| `NEXT_PUBLIC_WAYPOINT_CONSOLE_URL` | Ссылка на консоль WaypointMetric (кнопки/CTA) |
| `NEXT_PUBLIC_LYNX_HUB_URL` | Ссылка на публичный Lynx Hub (скачивание приложения) |
| `NEXT_PUBLIC_NEXUS_API_BASE` | Устаревший alias для API base (поддержка совместимости) |
| `REDIS_URL` | Для `npm run worker` |

Прод-шаблон переменных: `nexus-cloud/.env.example`.
