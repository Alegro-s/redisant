# Первый проект в Lynx

Краткий гайд: от установки до Play и экспорта.

## 1. Установка

1. Установите **Lynx Launcher** (`Lynx-Launcher.msi`).
2. В Hub откройте **Lynx Engine** и импортируйте `.lynxengine` (или скачайте с [lynx-hub.ru](https://lynx-hub.ru)).
3. Без Engine вкладка **Play** и embedded preview в редакторе не запустятся.

## 2. Создание проекта

**Локально**

- Hub → **Проекты** → «Новый проект» → шаблон (например **Tetris** или **Platformer**).
- Launcher создаст `project.json`, `.lynx/engine_lock.json` и откроет **Lynx Editor**.

**Из архива**

- Hub → **Tetris demo** — сохранить `Tetris-Demo.lynxproject`.
- Hub → **Импорт ZIP** — выбрать `.lynxproject` или `.zip` с `project.json` в корне.

## 3. Редактор

| Область | Действие |
|---------|----------|
| Sidebar | Фильтры ассетов, **Звук**, проводник |
| Холст | Pan/zoom, drag объектов, вкладки **сцен** |
| Inspector | Свойства, **Blueprint** (`Ctrl+Shift+B`) |
| Play (F5) | Запуск через установленный Engine |

Горячие клавиши: **F1** или **Ctrl+/** в редакторе.

## 4. Скрипты и Blueprint

- Текстовые скрипты: `assets/scripts/*.lua`
- **LynxScript / Blueprint**: визуальный граф → sidecar `*.graph.json` → компиляция в `.lua`
- Открыть: кнопка **Blueprint** в редакторе скрипта или инспекторе

## 5. Спрайты и звук

- Двойной клик по спрайту → **Sprite Editor** (кисти 1–4, undo по штриху, экспорт PNG)
- Звук: импорт WAV/OGG → sidebar **Звук** → preview; в Lua: `play_sound("id")`

## 6. Комнаты и несколько сцен

- Вкладки над холстом — отдельные JSON в `scenes/`
- Меню ⋮ → **Комнаты камеры** → зона может ссылаться на **сцену-холст** (`targetSceneId`)

## 7. Экспорт игры

В редакторе: **Файл → Экспорт** (Windows / Web / Android / data bundle).

Структура Windows-сборки:

```
MyGame/
  bin/engine.dll
  game_data/          # scenes, assets, project.json
```

Подробнее: [EXPORT.md](EXPORT.md), [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md).

## 8. Эталон Tetris

Шаблон `projects/tetris-demo/`:

- `480×640`, logic grids, полная логика в `assets/scripts/tetris.lua`
- Проверка: F5 в редакторе, стрелки / WASD, rotate, hard drop

## 9. Облако (опционально)

Войдите в аккаунт Lynx Hub → облачный проект привязан к версии Engine на сервере. Локальные проекты работают offline (`mode: offline`).

---

**Сборка Launcher MSI (разработчикам):**

```powershell
cd Lynx\scripts
.\build-lynx-launcher-msi.ps1
```

**Регрессия Wave 5:**

```powershell
cd Lynx\scripts
.\run-wave5-regression.ps1
```
