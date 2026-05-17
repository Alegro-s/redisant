# Вывод на сервер (Waypoint · Roza · Lynx)

## 1. База и API

```bash
cd d:\PO\deploy
docker compose -f docker-compose.split.yml up -d --build
# миграции применяются при старте auth-api (sqlx)
docker compose -f docker-compose.split.yml -f docker-compose.roza.yml up -d --build
```

Порты:
| Сервис | Порт |
|--------|------|
| auth-api | 8090 |
| waypoint-api | 8080 |
| lynx-api | 8082 |
| roza-api | 8765 |
| Postgres | 5432 (внутри compose) |

## 2. Переменные (прод)

- `JWT_SECRET` — минимум 32 символа
- `CORS_ALLOWED_ORIGINS` — домены Roza, Lynx Hub, Lynx Cloud
- `ROZA_PUBLIC_URL` — https://ваш-домен/roza
- SMTP для писем подтверждения (auth-api)
- Stripe/YooKassa — когда включите оплату (сейчас отключена в UI)

## 3. Статика

- **Roza web**: `npm run build` в `roza/web` → nginx `/roza`
- **Lynx Hub**: `npm run build` в `Lynx/hub` → nginx
- **Lynx Cloud**: `npm run build` в `Lynx/cloud` → nginx

Прокси nginx:
- `/auth` → auth-api:8090
- `/api`, `/ws` → roza-api:8765

## 4. Десктоп Roza AI

Сборка: `dotnet publish companion/RozaCompanion -c Release`  
Вход: те же логин/пароль, что на сайте `/account`.

## 5. Lynx Hub — Lynx Cloud

В шапке Hub ссылка **Lynx Cloud** (не Yandex Cloud).  
`VITE_LYNX_CLOUD_URL=https://lynx-cloud.ru`
