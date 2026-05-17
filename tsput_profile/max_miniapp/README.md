# MAX Mini App (мессенджер MAX)

Официально мини-приложения MAX — это **веб-приложение по HTTPS** внутри WebView и мост **MAX Bridge** ([документация](https://dev.max.ru/docs/webapps/bridge)).

## Рекомендуемый вариант для этого проекта

1. Собери **Flutter Web** и отдавай его через **nginx** из `docker compose` (профиль `web`), чтобы и UI, и `/api` были на одном домене.

2. В кабинете партнёра MAX укажи URL вида `https://твой-домен.ru/` (только HTTPS).

3. При необходимости подключи скрипт Bridge в `web/index.html` после сборки (см. dev.max.ru) — для базового демо достаточно открытия страницы без Bridge.

## Сборка

Из корня репозитория:

```bash
# Linux/macOS
./scripts/build_web_for_max.sh https://твой-домен.ru

# Windows PowerShell
.\scripts\build_web_for_max.ps1 -IntegrationBaseUrl https://твой-домен.ru
```

Затем:

```bash
docker compose --profile web up -d --build
```

Подробности — в `deploy/README.md`.

## Альтернатива: только HTML/JS

Если нужен минимальный прототип без Flutter, создай статику в отдельной папке и положи за nginx; для полноценного приложения удобнее единый Flutter Web.
