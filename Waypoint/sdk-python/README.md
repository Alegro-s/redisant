# Waypoint Metrics Python Client

Клиент для отправки **метрик и логов** в **WaypointMetric** — продукт наблюдаемости и backend-данных для **сайтов и приложений**, не для версионирования игрового движка NEXUS (это в Nexus Cloud / `GET /engine/manifest`).

Send metrics and logs to WaypointMetric from your Python applications.

## Installation

```bash
pip install waypoint-metrics
```

## Tests

Из каталога `WaypointMetrics`:

```bash
python -m unittest discover -v
```

Из корня репозитория `NEXUS`:

```bash
python -m unittest discover -s WaypointMetrics/tests -v
```

Раньше при запуске без `-s` из `WaypointMetrics` тесты не находились: нужен пакет `tests` — добавлен файл `tests/__init__.py`.