# Lynx Cloud API — волна 8

## Сервис `lynx-server`

Каталог: `Lynx/server/`

### Запуск (dev)

```powershell
cd Lynx/server
$env:LYNX_SERVER_DATA = "$PWD\data"
$env:LYNX_SERVER_PORT = "8080"
cargo run
```

Проверка:

```powershell
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/v1/marketplace/catalog
```

### Эндпоинты

| Метод | Путь | Auth | Описание |
|-------|------|------|----------|
| GET | `/health` | — | `ok` |
| GET | `/v1/marketplace/catalog` | — | JSON каталог |
| POST | `/v1/marketplace/items/{id}/claim` | Bearer | Бесплатная лицензия |
| GET | `/v1/marketplace/items/{id}/download` | Bearer | ZIP из `data/packages/{id}.zip` |

### Данные

- `data/marketplace_catalog.json` — каталог
- `data/packages/*.zip` — пакеты для download
- `data/marketplace_licenses.json` — выданные лицензии (persist on shutdown)

### Nginx (prod)

Проксируйте префикс `/lynx` на `127.0.0.1:8080` вместе с существующим API или объедините маршруты в один бинарник.

Launcher: при входе в аккаунт каталог грузится с `AuthProvider.http` → `/v1/marketplace/catalog`.

Для локальной отладки в профиле укажите сервер `http://127.0.0.1:8080` (база API станет `http://127.0.0.1:8080/lynx` после нормализации — при необходимости используйте прямой URL в `storeCatalogUrl`).

### Монетизация (не в бете)

В бета-тестировании все пакеты бесплатны: `POST claim` выдаёт лицензию без проверки `price`. См. [BETA_FREE.md](BETA_FREE.md). Billing — отдельный этап после беты.
