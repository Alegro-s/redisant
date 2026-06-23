# Lynx API

Бэкенд Lynx собирается из общего крейта **`D:\PO\platform\server`**, бинарник **`lynx-api`** (порт **8082**).

```bash
cd D:/PO/platform/server
export PO_SERVICE=lynx
export DATABASE_URL=postgres://waypoint:waypoint@127.0.0.1:5432/waypoint
export JWT_SECRET=1yXJxD99yzMsuUZVW8PNr9Y3kVovjW5ZA64jw4g2yHDUfkiG
cargo run --bin lynx-api
```

Продакшен: `deploy/docker-compose.split.yml` (сервис `lynx-api`).

Вход пользователей — через **auth-api** (`:8090`): общий JWT и cookie `waypoint_session`.
