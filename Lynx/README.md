# Lynx

**Lynx** — платформа 2D-игр и студии разработки (бывшее имя **NEXUS**).

| Зона | Каталог | Для кого |
|------|---------|----------|
| **Движок** | `engine/` | Rust-рантайм: сцена, Lua, физика, FFI для клиента |
| **Редактор** | `client/` | Flutter: редактор сцен, Play, облачные проекты |
| **Hub** | `hub/` | Сайт продвижения движка и экосистемы |
| **Cloud** | `cloud/` | Личный кабинет разработчика: проекты, сборки, статистика, команда |
| **Интеграции** | `integrations/` | DB agent, webhooks |
| **Деплой** | `deploy/`, `scripts/` | VPS, systemd для Cloud |

## API

HTTP API для Cloud и клиента в альфе поднимается из соседнего репозитория **[Waypoint](../Waypoint/)** (`api/`, порт `8080`). В профиле Flutter и в `.env` Cloud укажите URL этого API.

```powershell
cd D:\PO\Waypoint
docker compose up -d --build
```

## Локальная разработка

```powershell
# API (из Waypoint)
cd D:\PO\Waypoint
docker compose up -d --build

# Hub — :5175
cd D:\PO\Lynx\hub
npm run dev

# Cloud — :3001
cd D:\PO\Lynx\cloud
npm run dev

# Flutter
cd D:\PO\Lynx\client
flutter run
```

Скрипт «всё сразу»: `WITH_FRONTENDS=1 ./scripts/lynx-local.sh` (Git Bash / WSL).

## Документация

- `docs/LYNX_DOMAINS_AND_DEPLOY.md` — домены, nginx
- `docs/GAME_AUTHOR.md` — формат сцены, редактор (если перенесён в Lynx/docs)
- [`../Waypoint/docs/`](../Waypoint/docs/) — общие операции API

## Не входит в Lynx

- Веб-консоль **метрик и ingest** → [`../Waypoint/web`](../Waypoint/web)
- CRM **Agler** → [`../agler`](../agler)
- **RozaGPT** → [`../roza`](../roza)
