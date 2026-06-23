# Tetris Demo (Lynx Engine)

Готовый проект для проверки Lynx Engine: логика на Lua, отрисовка через `logic_grids`.

## Управление

- **A / ←** — влево
- **D / →** — вправо
- **W / Space** — поворот
- **S / ↓** — мягкий сброс
- **Enter** — жёсткий сброс

## Как открыть

1. Установите **Lynx Launcher** и импортируйте **Lynx Engine** (`.lynxengine`) в Hub.
2. Launcher → **Проекты** → открыть папку `tetris-demo` или создать из шаблона **Tetris**.
3. Вкладка **Игра** — предпросмотр; **Играть** — полный экран.

## Структура

- `project.json` — настройки (480×640)
- `scenes/main.json` — сцена с контроллером `tetris.lua`
- `assets/scripts/tetris.lua` — полная логика Tetris
