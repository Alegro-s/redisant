# Отчёт по тестированию `tsput_profile-master` (архив RAR)

**Дата:** 02.06.2026  
**Архив:** `tsput_profile-master.rar` (~458 МБ)  
**Распаковка:** `D:\PO\_tsput_from_rar\tsput_profile-master`  
**Сравнение с:** `D:\PO\tsput_profile` (ваша рабочая копия в монорепо PO)

---

## 1. Что это за продукт

Мобильное / веб-приложение **«ТГПУ профиль»** (Flutter) + **интеграционный backend** (FastAPI, mock-режим).

- Вход → REST `POST /api/auth/login`
- Данные: студент, расписание, оценки, экзамены, портфолио, лабораторные Moodle, партнёрские услуги (QR)
- Деплой: Docker Compose + nginx (опционально Flutter Web)

В архиве лежит **снимок проекта** (папка `master`), собранный на машине разработчика **~30–31.05.2026** (даты файлов, `build/`, `.dart_tool/`, даже `backend/venv`).

---

## 2. Результаты автоматических тестов API (архив, mock)

Стенд: `uvicorn` из архива, `MOCK_MODE=true`, порт **8083** (после перезапуска).

| Проверка | Результат |
|----------|-----------|
| `GET /health` | OK (`mock_mode: true`) |
| `POST /api/auth/login` (demo `student@university.ru` / `password123`) | OK |
| `POST /api/auth/login` (тест `test@tspu.local` / `TestTspu2026!` через `local_users.json`) | OK |
| Неверный пароль | OK (`success: false`) |
| `GET /api/student` + Bearer | OK |
| `GET /api/schedule` | 4 записи |
| `GET /api/grades` | 5 записей |
| `GET /api/exams` | 1 запись |
| `GET /api/portfolio` | 7 записей |
| `GET /api/moodle/labs` | 1 запись |
| `GET /api/partner-services` | 0 записей |
| `POST /api/sync` | OK |
| `GET /api/labs`, `/api/events` | **404** (в коде нет таких путей; лабы — только `/api/moodle/labs`) |
| CORS (Flutter Web) | Изначально **не было** → браузер «Failed to fetch»; **исправлено** добавлением `CORSMiddleware` |
| `flutter test` | **Провал** — шаблонный тест счётчика, не соответствует приложению |

**Вывод по API:** mock-backend из архива **работоспособен**; для Web обязателен CORS.

---

## 3. Сравнение архива и `D:\PO\tsput_profile`

| Метрика | Значение |
|---------|----------|
| Файлов только в архиве | 7 (в т.ч. `REAL_INTEGRATION.md`, `structure.txt`, `schedule_document.dart`) |
| Файлов только в PO | 65+ (лабы, splash, week plan, скрипты деплоя, UI-правки) |
| Общих файлов с **разным содержимым** | **158** |

### 3.1. Что делал автор архива (по содержимому)

1. **Документация интеграции** — `REAL_INTEGRATION.md`: план подключения **1С + Moodle + портфолио**, API-first, без локальных JSON; чеклист production.
2. **Backend mock** — FastAPI с демо-логином, опционально `local_users.json`, **без** предзаполненных Moodle-полей в `docker-compose.yml` (в PO они добавлены под конкретного студента).
3. **Роли пользователя** — в архиве в `auth_provider.dart` есть поле **`userRole`** / `role` в ответе login (задел под админ/студент); в PO — доработан `rememberMe` и auto-login через `AuthService`.
4. **Модель `schedule_document.dart`** — только в архиве (доп. сущность расписания; в PO не перенесена).
5. **Сборка «как есть»** — в архив попали `build/`, `.dart_tool/`, `backend/venv` (типичный экспорт «всей папки проекта», не чистый git clone).
6. **Визуальный редизайн** — в PO **после** архива: витрина (showcase), профиль с terracotta-блоками, лабораторные Moodle, план недели, splash — этого в архиве **нет** или версия старее.

### 3.2. Что есть в PO, но не в архиве (ваши доработки)

- `labs_screen`, `LabsProvider`, Moodle labs API
- `entry_splash_screen`, `week_schedule_plan_table`
- `backend/КАК_ВОЙТИ.txt`, настроенный `local_users.json`
- Расширенный `docker-compose` (карточка студента в env)
- CORS в `main.py` (добавлено при тестах)
- UI: оформление профиля, динамическая витрина, центрирование расписания/сервисов (последняя сессия)

### 3.3. Критичная разница для «не грузится по IP»

В **обеих** версиях `lib/core/integration_runtime.dart`:

```dart
static const String _production = 'http://72.56.244.26:8080';
```

Если запустить Flutter **без** `--dart-define=INTEGRATION_BASE_URL=...`, приложение идёт на **удалённый VPS**, а не на localhost → у вас «по IP не грузится», на localhost — только если API локально проброшен или кэш старой сборки.

---

## 4. Почему на localhost не было UI-изменений

1. Открыт **старый процесс** `flutter run` (до правок) — нужен **hot restart (R)** или полный перезапуск скриптом.
2. Запуск **не из** `D:\PO\tsput_profile`, а из распакованного архива (там другой код).
3. Сборка **без** `INTEGRATION_BASE_URL` → запросы на `72.56.244.26:8080`, а не на локальный API.

---

## 5. Учётные данные для тестов

| Назначение | Логин | Пароль |
|------------|--------|--------|
| Demo (встроенный в backend) | `student@university.ru` | `password123` |
| Тестовый (`local_users.json`) | `test@tspu.local` / `99999` / `Тестовый Студент` | `TestTspu2026!` |

---

## 6. Рекомендации

- **Архив** — референс / интеграционная документация; основная разработка — **`D:\PO\tsput_profile`**.
- Для локальной работы всегда использовать скрипты запуска с `INTEGRATION_BASE_URL`.
- Перед сравнением UI — один порт, один каталог, жёсткий restart Flutter.
- Админка/CMS — имеет смысл на backend, когда новости витрины нужны всем пользователям (см. обсуждение в чате).

---

## 7. Команды воспроизведения

См. `scripts/start-tsput-po-dev.ps1` и `scripts/start-tsput-archive.ps1` в `tsput_profile`.
