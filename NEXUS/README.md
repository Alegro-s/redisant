# NEXUS (архивное имя)

Платформа переименована и **разделена по папкам `D:\PO`**:

| Было в монорепо NEXUS | Сейчас |
|----------------------|--------|
| `server/` | [`../Waypoint/api/`](../Waypoint/api/) |
| `admin-panel/` | [`../Waypoint/web/`](../Waypoint/web/) |
| `WaypointMetrics/` | [`../Waypoint/sdk-python/`](../Waypoint/sdk-python/) |
| `client/`, `engine/` | [`../Lynx/client/`](../Lynx/client/), [`../Lynx/engine/`](../Lynx/engine/) |
| `nexus-cloud/`, `nexus-hab/` | [`../Lynx/cloud/`](../Lynx/cloud/), [`../Lynx/hub/`](../Lynx/hub/) |
| `vk-bot/` | [`../Waypoint/vk-bot/`](../Waypoint/vk-bot/) |
| `scripts/` (деплой) | [`../Waypoint/scripts/`](../Waypoint/scripts/), [`../deploy/`](../deploy/) |

## Не используйте этот каталог для новой разработки

Актуальная карта экосистемы: **[`../README.md`](../README.md)**.

## Локальный запуск (актуально)

```powershell
cd D:\PO\Waypoint
docker compose up -d --build
cd D:\PO\Waypoint\web
npm run dev
```
