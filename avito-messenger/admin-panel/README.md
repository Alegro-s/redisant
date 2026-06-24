# Neural Trust — панель оператора

Статический фронтенд. Все данные приходят с gateway по HTTP.

## Запуск

```bash
cd console-ui
npx serve -l 5173
```

## Подключение API

В `index.html` перед `js/app.js`:

```html
<script>window.NT_API_URL = "http://localhost:3000";</script>
```

Интервал опроса: `js/config.js` → `pollMs` (по умолчанию 15000).

CORS на gateway должен разрешать origin панели.

## Структура проекта

| Путь | Назначение |
|------|------------|
| `index.html` | разметка, `NT_API_URL`, подключение стилей и `js/app.js` |
| `css/tokens.css` | цвета, размеры |
| `css/base.css` | layout, секции |
| `css/components.css` | компоненты |
| `js/config.js` | URL API, интервал опроса |
| `js/app.js` | навигация, опрос, команды |
| `js/core/state.js` | состояние панели |
| `js/api/client.js` | запросы к gateway |
| `js/lib/format.js` | форматирование чисел |
| `js/views/*.js` | экраны: обзор, пользователи, алерты, журнал |
| `js/commands/registry.js` | CLI внизу страницы |
## Экраны

- **Обзор** — метрики системы, трафика, безопасности, детекции, токены, статусы сервисов
- **Пользователи** — список, блокировка / разблокировка
- **Алерты** — срабатывания правил
- **Журнал** — события аудита

## Команды CLI

`обновить` · `блок <id> [причина]` · `разблок <id>`

Контракт REST: `/docs` на gateway (Swagger).
