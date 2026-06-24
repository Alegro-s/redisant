# Экосистема: Lynx Hub + Lynx Cloud

## Роли

| Продукт | Назначение |
|---------|------------|
| **Lynx Hub** (`hub/`) | Сайт: новости, ядра, ссылки на Launcher, витрина маркетплейса |
| **Lynx Launcher** (`client/`, `main.dart`) | Hub в приложении: проекты, Cloud каталог, мессенджер |
| **Lynx Editor** (`main_editor.dart`) | Редактор сцен, Play, export |
| **Lynx Cloud** | API: облачные проекты, каталог, лицензии, сборки (backend вне репо) |

## Каталог маркетплейса v1

Файл-эталон: `hub/public/content/marketplace-catalog.json`  
Копия для офлайн Launcher: `client/assets/marketplace/default_catalog.json`

```json
{
  "apiVersion": 1,
  "updatedAt": "2026-06-02T00:00:00Z",
  "items": [
    {
      "id": "lynx.3d",
      "kind": "plugin",
      "title": "Lynx 3D",
      "category": "plugins",
      "version": "0.2.0",
      "engineMinVersion": "1.2.0",
      "builtin": true,
      "description": "3D сцены, GLB, orbit viewport"
    }
  ]
}
```

### Поля `items[]`

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | string | Уникальный id пакета |
| `kind` | `plugin` \| `template` \| `asset_pack` \| `engine_core` | Тип установки |
| `title` | string | Название |
| `category` | `plugins` \| `3d` \| `2d` \| `audio` \| `templates` \| `tools` | Фильтр в Launcher |
| `version` | string | Semver пакета |
| `engineMinVersion` | string? | Минимум Lynx Core |
| `price` | number? | Зарезервировано; в **бете** всегда 0 / не используется — см. [BETA_FREE.md](BETA_FREE.md) |
| `packageUrl` | string? | ZIP для скачивания (CDN Cloud) |
| `templateId` | string? | для `kind: template` → `lynx_project_templates` |
| `builtin` | bool? | встроен в Launcher, без ZIP |
| `pluginId` | string? | для `kind: plugin` → `lynxPlugins.enabled` |

## Установка в Launcher (код)

`client/lib/features/ecosystem/lynx_marketplace.dart`:

- `LynxMarketplace.fetchCatalog(url)`
- `LynxMarketplace.installIntoProject(projectRoot, item)`

## Hub

Страница Download / Projects ссылается на каталог.  
Переменная `VITE_MARKETPLACE_CATALOG_URL` → JSON (опционально).

## Cloud API (волна 8 ✅)

Реализация: `Lynx/server/` (`lynx-server`).

```
GET  /v1/marketplace/catalog
POST /v1/marketplace/items/{id}/claim   (Bearer)
GET  /v1/marketplace/items/{id}/download (Bearer)
```

Launcher: при авторизации — Cloud API; иначе bundled `assets/marketplace/default_catalog.json`.

См. [CLOUD_API_WAVE8.md](CLOUD_API_WAVE8.md).

## Кабинеты после входа (2026-06)

| Сайт | URL после login | Назначение |
|------|-----------------|------------|
| **Lynx Hub** | `/account` (обычный пользователь) или `/admin` (NEXUS) | Маркетплейс, загрузки, ссылка на Messenger в Launcher |
| **Lynx Cloud** | `/cabinet/dashboard` | Проекты, сборки, аналитика, доход, ключи |
| **Lynx Cloud Ops** | `/admin` | Engine, S3-загрузки, все проекты (только NEXUS) |

Один аккаунт (`lynx_auth_token` в localStorage **на каждом домене отдельно**). Hub не редиректит на Cloud после входа.

### Роль NEXUS / ops

- В БД: `users.role = 'nexus'`
- Env fallback: `LYNX_OPS_EMAILS=rozalityai@gmail.com` (через запятую)
- Миграция `20260623120000_lynx_analytics_storage.sql` повышает `rozalityai@gmail.com` до nexus

### API кабинета (lynx-api)

```
GET  /me/lynx-cloud/overview     — KPI: проекты, сборки, скачивания, сессии, баланс
GET  /me/lynx-cloud/analytics    — ряд за 30 дней
POST /me/lynx-cloud/telemetry    — { project_id, duration_sec }
POST /admin/storage/presign      — S3 presigned PUT (NEXUS)
POST /admin/storage/upload       — multipart fallback
POST /admin/engine/artifacts     — merge manifest после загрузки .lynxengine
```

### S3 (twcstorage)

Env на lynx-api:

```
LYNX_S3_ENDPOINT=https://s3.twcstorage.ru
LYNX_S3_BUCKET=bc39a46d-ee3d-4707-9e3f-9529afb602da
LYNX_S3_ACCESS_KEY=...
LYNX_S3_SECRET_KEY=...
LYNX_S3_PUBLIC_BASE=https://lynx-hub.ru/dist/downloads
LYNX_ENGINE_MANIFEST_S3_KEY=deploy/sites/latest/dist/downloads/engine-manifest.json
```

### Деплой на VPS

```bash
cd /opt/waypoint/redik && git pull
sudo bash deploy/ecosystem/scripts/server-repair-apis.sh
sudo bash deploy/ecosystem/scripts/server-restart-lynx-cloud.sh
# Hub: пересборка статики с VITE_LYNX_API_BASE
```

