# PO — монорепозиторий экосистемы Waypoint

## Домены

| Домен | Роль |
|-------|------|
| **waypointclub.ru** | Waypoint Club — главный сайт экосистемы |
| **metrika-waypoint.ru** | Waypoint Metric (облако) |
| **metrika-waypoint.ru/desktop** | Waypoint Desktop — подраздел Metric (как Roza на Club) |
| **waypointclub.ru/roza** | Подсерия Roza |
| **waypointclub.ru/tspu** | ТГПУ Профиль |
| **lynx-hub.ru**, **lynx-cloud.ru** | Lynx — отдельные домены |

## Локальный Docker

```powershell
cd D:\PO\deploy\ecosystem
.\scripts\start-local-docker.ps1 -Build
```

| URL | Продукт |
|-----|---------|
| http://127.0.0.1:3000 | Club |
| http://127.0.0.1:3002 | Metric |
| http://127.0.0.1:3002/desktop | Desktop |
| http://127.0.0.1:3000/roza | Roza |
| http://127.0.0.1:3000/tspu | ТГПУ |

## Сборка установщика Desktop

```powershell
D:\PO\deploy\ecosystem\scripts\pack-waypoint-desktop.ps1
```

Файлы: `releases/waypoint-desktop/` и `Waypoint/web/public/downloads/` (раздаётся с Metric как `/downloads/`).

## Деплой

`deploy/ecosystem/README.md`, на сервере `bash /root/deploy-all.sh` после `git pull`.
