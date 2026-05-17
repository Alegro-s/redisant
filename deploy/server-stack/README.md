# Server stack (Waypoint + Lynx + TSPUT)

Оркестрация на одном VPS. Задайте пути в `paths.env` (см. `paths.env.example`).

| Скрипт | Действие |
|--------|----------|
| `git-pull-all.sh` | `git pull` в Waypoint, Lynx, tsput_profile |
| `nexus-docker-up.sh` | Docker Compose в **Waypoint** (API :8080) |
| `pull-and-rebuild-all.sh` | pull + `lynx-server-deploy.sh` (+ TSPUT опционально) |
| `tsput-docker-up.sh` | Стек TSPUT (:8081) |

Legacy-имя `NEXUS_ROOT` = `WAYPOINT_ROOT`.
