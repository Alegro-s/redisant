# Диплом Lynx 2D — расширение текста (для 80+ стр.)

> Вставьте содержимое **после** соответствующих разделов файла `DIPLOMA_LYNX_2D_ENGINE.md` при верстке в Word.

---

## Расширение 1.1 — Детальный анализ предметной области

Разработка двумерных игр в учебной среде исторически сталкивалась с дилеммой: использовать готовый коммерческий движок (Unity, Construct) и ограничиться поверхностным пониманием, либо писать «с нуля» на SDL/OpenGL и потратить семестр на инфраструктуру вместо геймплея. Lynx занимает промежуточную позицию — **готовый редактор и Play**, но **открытое Rust-ядро** и документированный JSON v3, что позволяет дипломанту показать и продуктовую, и инженерную составляющие.

Жанр платформера остаётся эталоном для проверки движка: гравитация, коллизии, анимация по состоянию, камера, враги с простым AI. Проект `platformer-demo` в репозитории Lynx специально служит **реgression anchor** волны 0: любое изменение в `animation.rs` или `tilemap_layer_painter.dart` должно сохранять визуальное совпадение Play и редактора. Это качественный критерий, превосходящий простой «компилируется без ошибок».

С точки зрения программной инженерии 2D-игра — система с жёстким real-time constraint (16,7 ms на кадр при 60 FPS). Бюджет времени распределяется между симуляцией, отрисовкой и вводом-выводом (`PERFORMANCE_BUDGET.md`). Lynx закладывает ≤4 ms на Rust `scene_update`, оставляя Flutter до 8 ms на paint — разумное разделение для сцен с десятками спрайтов и одним-двумя слоями тайлмапа.

Формат сцены v3 эволюционировал от ранних версий NEXUS; поле `formatVersion: 3` сигнализирует клиенту и серверу о наборе полей (tilemaps, rooms, extensions). Обратная совместимость поддерживается на уровне парсеров Dart и Rust; миграции — ответственность скриптов при major bump. Для диплома важно подчеркнуть: **стабильность контракта** — prerequisite кроссплатформенности.

---

## Расширение 1.2 — Параллельная реализация: кейсы

**Кейс A — студенческая группа.** Три студента параллельно разрабатывают уровни `level1.json`, `level2.json`, `level3.json` в одном `project.json`. Autoload подключает `hud.json` с общим UI. Преподаватель проверяет каждый уровень через `startupSceneId` или временную подмену. Merge в Git — только JSON, конфликты видны в diff. Collab-сессия (при доступном API) снижает риск перезаписи.

**Кейс B — indie-автор.** Одна игра, три канала дистрибуции: Steam (Windows build из export), браузерная demo (Web), мобильная версия (Android). Логика на Lua/LynxScript общая; рендер на Web идёт через Dart fallback — автор документирует отличия в README игры.

**Кейс C — регрессия CI.** Параллельный запуск `run-wave0-regression.ps1` и `run-wave11-regression.ps1` на pull request (задел GitHub Actions). Падение любого скрипта блокирует merge — промышленная практика, редкая для учебных проектов, но реализуемая в Lynx.

---

## Расширение 1.3 — Таблица SMB parity (полная)

| Требование SMB | Lynx | Комментарий для диплома |
|----------------|------|-------------------------|
| Большой тайлмап | ✅ редактор + ядро | Play требует корректный atlas |
| One-way, склоны | ✅ TILE_* | Полировка contact — настройка |
| Motor + coyote | ✅ PlatformerMotor | SMB-«feel» — ручная настройка |
| BT враги | ✅ JSON BT | Нет визуального BT-редактора |
| Anim SM | ✅ | Меньше контента, чем Unity |
| Camera dead zone | ✅ Camera2D | Согласовать preview |
| Multi-room | ✅ rooms | Дизайн уровней |
| Audio buses | ✅ очереди | Без FMOD |
| Gamepad | ✅ FFI | Touch UI — базовый |

**Вывод для диплома:** Lynx — **средний** уровень сложности платформера; не AAA, но выше «hello world» на чистом SDL.

---

## Расширение 2.1 — Модули engine (описательный каталог)

**scene.rs** — центральная структура: вектор сущностей, tilemaps, rooms, очереди сигналов и звука. Метод `update` orchestrates подсистемы. Сериализация serde для JSON обмена с Dart.

**platformer.rs** — tile collision types, motor integration, grid broadphase. Критичен для дипломной демонстрации «физика в Rust, не в Dart».

**animation.rs** — EntityAnimator, uv_rect propagation (волна 0). Без этого Play показывает статичный спрайт — типичный баг student projects.

**behavior_tree.rs** — tick BT после Lua, до patrol. Позволяет комбинировать скриптовую и declarative AI логику.

**lua/** — mlua bindings, `load_scene`, globals. Legacy path; LynxScript — replacement per roadmap M5.

**lib.rs (FFI)** — `scene_create`, `scene_update`, `scene_set_gamepad`, export JSON pointer. Dart `engine_bridge` — thin wrapper.

---

## Расширение 2.2 — Пошаговый алгоритм Play (нарратив)

При нажатии Play клиент загружает `startupSceneId`, merge autoload сцен, сериализует в engine JSON, создаёт native scene pointer. Ticker вызывает update с clamped dt. Rust выполняет полный pipeline (Lua→BT→motor→physics→camera). Dart читает state, для каждого visible object вычисляет screen position через camera transform, рисует sprite rect из uv_rect, затем tile layers sorted by layer order. Audio events dequeue to audioplayers. При pause — `scene_set_paused` stops simulation but UI remains. При unload — destroy pointer, GC Dart side.

Этот нарратив можно оформить как **рисунок последовательности UML** (8–10 сообщений между Flutter, FFI, Rust) — +2 страницы в Word.

---

## Расширение 2.3 — Export pipeline (детально)

1. `export-player.ps1` читает `-Project` path.  
2. Копирует `scenes/`, `assets/`, `project.json` в `game_data/`.  
3. Preset `windows`: добавляет `engine.dll`, `LynxPlayer.exe` (или flutter build windows).  
4. Preset `web`: `flutter build web` с `main_player.dart`.  
5. Preset `android`: `flutter build apk` + pack copy.  
6. Manifest/metadata для itch.io / Play Store — вне scope движка.

Параллельность: шаги 3–5 могут выполняться одним вызовом `-Preset all` — ключевой аргумент диплома о **parallel implementation**.

---

## Расширение 3.1 — Перечень автотестов (пример)

| Файл теста | Что проверяет |
|------------|---------------|
| `wave0_platformer_demo_test.dart` | demo project assets |
| `wave2_*` | scene manager |
| `engine` unit | physics grid |
| `client/test/wave9_*` | animation events |
| `run-wave10-regression.ps1` | BT |

Студент в дипломе приводит **скриншот** вывода `cargo test` и `flutter test` — доказательство исполнения.

---

## Расширение 3.2 — Протокол ручного теста (образец заполнения)

**Сценарий 2. Play = Editor**  
Дата: ___. ОС: Windows 11. Разрешение: 1920×1080.  
Шаги: открыть demo → Play 60 с → screenshot compare.  
Результат: совпадение UV кадра бега — **да**.  
Подпись: ___.

*(Повторить для сценариев 1–10 — таблица протокола на 3–4 страницы.)*

---

## Листинги для приложений (увеличение объёма)

### player.lua (фрагмент, типичный)

```lua
function _ready()
  -- init
end

function _physics_process(dt)
  local vx = 0
  if action_left() then vx = vx - 1 end
  if action_right() then vx = vx + 1 end
  set_velocity(vx * run_speed, get_velocity_y())
end
```

### Dart: scene_to_engine_json (концепт)

Экспорт сцены из редактора собирает tilemaps, objects, rooms в Map для Rust. Любое поле `properties.platformer_motor` маппится в motor component. Тест export roundtrip — в `client/test/`.

---

*Конец расширения. Вместе с основным файлом + 9 рисунков + протоколы ≈ 80 стр.*
