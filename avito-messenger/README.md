# YALGSI — AVITO Hackathon Messenger (AIShield)

Мессенджер с AI-модерацией, Mattermost backend, админ-панель.

| Компонент | Описание |
|-----------|----------|
| `backend/` | FastAPI API |
| `admin-panel/` | Веб-админка (`/admin` на API) |
| `docker-compose.prod.yml` | Postgres + API + Mattermost |

Полные исходники (Flutter-клиент `caht/`, сборки Linux) — у вас локально в  
`Учёба/Хакатоны/AVITO/Hac_zona/Hac_zopa`. В git — только серверная часть для деплоя.

## Деплой на VPS (тот же сервер, что Lynx)

```bash
cd /opt/waypoint/redik && git pull
sudo cp deploy/ecosystem/avito.env.example /opt/waypoint/avito.env
sudo nano /opt/waypoint/avito.env   # пароли и ADMIN_API_KEY
sudo bash deploy/ecosystem/scripts/server-deploy-avito.sh
```

Публично: **https://waypointclub.ru/yalgsi/** (API + `/admin` → `.../yalgsi/admin`)

Тестовый аккаунт (после seed): `superadmin` / `Admin123!`

## Локально

```bash
cd avito-messenger
cp .env.example .env
docker compose -f docker-compose.prod.yml up -d --build
curl http://127.0.0.1:8000/health
```

## Секреты

Не коммитьте `.env`, `secrets/*.json`, Firebase keys. Только `.env.example`.
