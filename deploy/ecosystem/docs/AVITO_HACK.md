# AVITO Hackathon — YALGSI Messenger

Проект **в репозитории**: [`avito-messenger/`](../../avito-messenger/) (backend + admin-panel + Docker).

Полный Flutter-клиент (`caht`) остаётся локально в `Учёба/Хакатоны/AVITO/Hac_zona/Hac_zopa`.

## Деплой на VPS

```bash
cd /opt/waypoint/redik && git pull

# Первый раз — env
sudo cp deploy/ecosystem/avito.env.example /opt/waypoint/avito.env
sudo nano /opt/waypoint/avito.env

sudo bash deploy/ecosystem/scripts/server-deploy-avito.sh
```

## URL после деплоя

| Что | URL |
|-----|-----|
| API + docs | https://waypointclub.ru/yalgsi/docs |
| Админ-панель | https://waypointclub.ru/yalgsi/admin |
| Тест-логин | `superadmin` / `Admin123!` |

## Проверка

```bash
curl -sI http://127.0.0.1:8000/docs | head -1
curl -sI https://waypointclub.ru/yalgsi/docs | head -1
docker ps | grep -E 'aishield|mattermost'
```

## Что заполнить в `/opt/waypoint/avito.env`

- `POSTGRES_PASSWORD`, `MM_DB_PASSWORD` — сильные пароли
- `ADMIN_API_KEY`, `SECURE_CONFIG_SEED` — случайные строки (32+ символов)
- `PUBLIC_HOST=https://waypointclub.ru/yalgsi`
- Опционально: Telegram, LM Studio, Firebase в `secrets/` (не в git)

## Lynx vs AVITO

Это **разные продукты** на одном VPS: Lynx (Hub/Cloud) и YALGSI (мессенджер хакатона). Общий только сервер и при желании SMTP.
