# Deploy — оркестрация на VPS

Скрипты для **нескольких продуктов** на одном сервере без монорепозитория NEXUS.

## Переменные

Скопируйте `server-stack/paths.env.example` → `server-stack/paths.env`:

| Переменная | По умолчанию | Продукт |
|------------|--------------|---------|
| `WAYPOINT_ROOT` | `~/Waypoint` | API + веб-метрики |
| `LYNX_ROOT` | `~/Lynx` | Hub, Cloud, Flutter-артефакты |
| `TSPUT_ROOT` | `~/tsput_profile` | TSPUT (порт 8081) |

## Типовые команды

```bash
cd /path/to/PO/deploy/server-stack
source paths.env   # или: set -a && source paths.env && set +a

# Pull всех репозиториев + пересборка Lynx-фронтов и Waypoint API
./pull-and-rebuild-all.sh

# Только Waypoint Docker
./nexus-docker-up.sh   # имя файла legacy; поднимает Waypoint compose

# TSPUT (опционально)
WITH_TSPUT_DOCKER=1 ./pull-and-rebuild-all.sh
```

См. [`server-stack/README.md`](server-stack/README.md).
