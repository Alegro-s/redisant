# Waypoint Desktop (Tauri)

Локальный клиент серии Waypoint: облако Metric, Docker, терминал, Liza.

## Разработка

```powershell
cd D:\PO\Waypoint\desktop
npm install
npm run tauri:dev
```

## Сборка

```powershell
npm run tauri:build
# или из корня PO:
D:\PO\deploy\ecosystem\scripts\pack-waypoint-desktop.ps1
```

## Переменные

- `VITE_WAYPOINT_CLOUD_URL` — сайт Metric (по умолчанию http://127.0.0.1:3002)
- `VITE_WAYPOINT_AUTH_URL` — auth-api (:8090)
- `VITE_WAYPOINT_API_URL` — waypoint-api (:8080)

## Deep link

`waypoint://pair?code=WD-XXXXXXXX` — подстановка кода привязки.
