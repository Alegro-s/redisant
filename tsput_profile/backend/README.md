# Backend for TSPUT Profile

Это backend-слой для Flutter-клиента.  
Он закрывает вопрос демонстрации "реального продукта" даже без URL от вуза.

## Docker (рекомендуется)

Из **корня репозитория** (не из `backend/`):

```bash
docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build
```

API: `http://localhost:8080/health`

**Демо-вход** (переменные `API_DEMO_*` в `docker-compose`):

- логин: `student@university.ru` · пароль: `password123`

**Вход как в Moodle** (на сервере задайте в `.env` рядом с `docker-compose.yml` или в `environment`):

- `MOODLE_STUDENT_ID` — числовой ID (например `24807`)
- `MOODLE_EMAIL` — почта из профиля Moodle (опционально)
- `STUDENT_FULL_NAME` — ФИО для входа по имени (опционально)
- `MOODLE_PASSWORD` — пароль от Moodle (обязателен для этих вариантов)

### Вход своим логином (без Moodle API) — `local_users.json`

В репозитории уже лежит **`backend/local_users.json`**: в нём список, чем можно войти (ID `24807`, почта, ФИО) и пароль по умолчанию **`password123`**.

**Что сделать:** откройте этот файл и замените `password123` на **ваш пароль от Moodle**. Подробно по шагам — файл **`backend/КАК_ВОЙТИ.txt`**.

Docker-образ копирует `local_users.json` внутрь контейнера (`Dockerfile`), после правки выполните `docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build`.

Полная инструкция (nginx, MAX, деплой): см. `deploy/README.md`.

## Что уже есть
- `POST /api/auth/login`
- `GET /api/student`
- `GET /api/schedule`
- `GET /api/grades`
- `GET /api/exams`
- `GET /api/portfolio`
- `GET /api/moodle/labs`
- `GET /health`

Ответ `GET /api/moodle/labs`: поля `id`, `course`, `title`, `status`, `teacherComment`, `updatedAt` и опционально `deadline`, `workType`, `theme`, `score` (для табеля в приложении).

Для альфы на сервере можно задать в `.env` или в `docker-compose` переменные **`STUDENT_CARD_*`**: тогда в приложении в профиле подставятся ваши `id`, ФИО, группа и почта (остальное поле пока из демо-шаблона в коде). Вход: `local_users.json` и/или `MOODLE_*` + `MOODLE_PASSWORD`, см. `КАК_ВОЙТИ.txt`.

Все endpoint'ы совместимы с текущими моделями в `lib/`.

## Быстрый запуск
1. Установи Python 3.11+.
2. В каталоге `backend/`:
   - `python -m venv .venv`
   - Windows: `.venv\Scripts\activate`
   - `pip install -r requirements.txt`
3. Создай `.env` на основе `.env.example`.
4. Запусти:
   - `uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload`

## Режимы работы
- `MOCK_MODE=true` — полностью рабочий демо-контур для продажи.
- `MOCK_MODE=false` — подключение к реальным системам (1C/Moodle), когда дадут URL и ключи.

## Как подружить с Flutter
Один параметр сборки:

```bash
flutter run --dart-define=INTEGRATION_BASE_URL=http://СЕРВЕР:8080
```

Или для Web/MAX (один HTTPS-домен с nginx):

```bash
flutter build web --release --base-href / --dart-define=INTEGRATION_BASE_URL=https://твой-домен.ru
```

Все запросы идут на `INTEGRATION_BASE_URL` + `/api/...`.

## Что добавить следующим шагом
- JWT refresh токены.
- PostgreSQL + таблицы snapshot/notifications.
- Реальные адаптеры 1C OData и Moodle `server.php`.
