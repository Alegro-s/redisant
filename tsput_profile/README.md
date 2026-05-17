Проект представляет собой мобильное приложение, разработанное на Flutter. Приложение предназначено для студентов и содержит функционал просмотра расписания, оценок, экзаменов, портфолио и профиля пользователя. Реализована авторизация через API, демо-вход **офлайн** (без сервера), интеграционный **backend в Docker** и сборка **Flutter Web для MAX Mini App**.

- **Docker:** `docker compose -f docker-compose.yml -f docker-compose.publish-8080.yml up -d --build` (см. `deploy/README.md`).
- **Сборка с API:** `flutter run --dart-define=INTEGRATION_BASE_URL=http://СЕРВЕР:8080`.
- **MAX Web:** `scripts/build_web_for_max.sh` / `.ps1`, см. `max_miniapp/README.md`.

### Сборка под Windows (desktop)

Плагин `flutter_secure_storage` для Windows тянет **C++ ATL**. Если при сборке ошибка **`atlstr.h: No such file or directory`**:

1. Открой **Visual Studio Installer** → **Изменить** установленную VS (2022 или 2026).
2. Вкладка **Отдельные компоненты** → найди **ATL** → включи, например:
   - **C++ ATL for latest v143 build tools (x86 & x64)** — для VS 2022, или  
   - аналог с **v145** / **latest** для твоей версии **VS 2026** (название в списке будет с номером toolset).
3. Установи, перезапусти терминал, при необходимости удали `build\windows` и снова `flutter run -d windows ...`.

Проверить API без нативной сборки Windows: `flutter run -d chrome --dart-define=INTEGRATION_BASE_URL=http://СЕРВЕР:8080`.

Технологический стек
Flutter (SDK) — основной фреймворк.

Dart — язык программирования.

Provider — управление состоянием.

HTTP (пакет http) — работа с REST API.

SharedPreferences / secure_storage — локальное хранение данных.

Layered Architecture — многослойная архитектура с чётким разделением ответственности.

Архитектура проекта
В проекте используется гибридная архитектура, сочетающая Layered Architecture и Repository Pattern с управлением состоянием через Provider. Основные слои:

1. Core (инфраструктурный слой)
   network.dart — настройка HTTP-клиента, интерсепторы, обработка ошибок.

auth_service.dart — логика авторизации (логин, логаут, обновление токена).

secure_storage.dart — работа с защищённым хранилищем (токены).

constants.dart — базовые URL, ключи, константы.

themes.dart — темы и стили приложения.

2. Data (слой данных)
   models/ — DTO/Entity классы (student.dart, grade.dart, exam.dart и др.). Содержат fromJson / toJson.

services/ — конкретные сервисы для работы с API (api_service.dart) и локальным хранилищем (local_storage.dart).

repositories/ — репозитории, реализующие бизнес-логику получения данных (student_repository.dart, grades_repository.dart и др.). Репозитории скрывают источник данных (сеть/кэш) и могут объединять несколько сервисов.

3. State Management (провайдеры)
   providers/ — классы, управляющие состоянием экранов (auth_provider.dart, schedule_provider.dart, events_provider.dart и др.). Каждый провайдер использует соответствующий репозиторий, хранит состояние загрузки и ошибок, уведомляет UI через notifyListeners().

4. UI (пользовательский интерфейс)
   screens/ — экраны приложения (home_screen.dart, schedule_screen.dart, profile_screen.dart, login_screen.dart).

widgets/ — переиспользуемые UI-компоненты (schedule_card.dart, info_tile.dart, loading_indicator.dart, profile_card.dart). Виджеты не содержат бизнес-логики, только отображение.

auth/ — экраны, связанные с авторизацией (например, login_screen.dart).

5. Utils (вспомогательные утилиты)
   date_utils.dart — форматирование и работа с датами.

grade_calculator.dart — логика расчёта среднего балла и другие вычисления.

6. Точка входа
   main.dart — инициализация приложения, подключение провайдеров, настройка темы и роутинга.