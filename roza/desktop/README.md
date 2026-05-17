# Roza AI Desktop (Windows)

Лёгкий клиент на Python вместо Avalonia — один экран входа и чат.

```powershell
cd d:\PO\roza\desktop
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python roza_desktop.py
```

Переменные окружения (опционально):

- `ROZA_AUTH_URL` — по умолчанию `https://waypointclub.ru/auth`
- `ROZA_API_URL` — по умолчанию `https://waypointclub.ru/roza/api`

Настройки сохраняются в `%USERPROFILE%\.roza\desktop.json`.

Сборка в `.exe` (опционально): `pip install pyinstaller` → `pyinstaller -w -F roza_desktop.py`
