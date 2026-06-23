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
