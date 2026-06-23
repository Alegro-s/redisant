# Lynx — дорожная карта волнами

План рассчитан на **спокойное** выполнение: каждая волна — отдельный релиз, с критериями готовности и без смены архитектуры (Rust-ядро + Flutter-клиент).

Связанные документы:

- [PLUGIN_SYSTEM.md](PLUGIN_SYSTEM.md) — плагины (в т.ч. 3D)
- [GAME_AUTHOR.md](GAME_AUTHOR.md) — формат сцены и авторский контент

---

## Принципы

1. **Не переписываем** стек: симуляция в Rust, окно/редактор/рендер во Flutter.
2. **Одна сцена — один контракт** JSON v3; расширения — через `extensions` и плагины.
3. **Веб** догоняет десктоп по волнам (сначала Dart `WebSceneEngine`, позже WASM).
4. Каждая волна заканчивается **демо-проектом** и чеклистом QA.

---

## Волна 0 — Стабильный Play ✅

**Цель:** то, что видно в редакторе, совпадает с Play на Windows.

| Задача | Результат | Статус |
|--------|-----------|--------|
| UV/кадр анимации из Rust в `sprite.uv_rect` | `engine/src/animation.rs`, клиент `sprite_uv_resolve.dart` | ✅ |
| Эталонный demo `projects/platformer-demo` | `scripts/run-wave0-regression.ps1` | ✅ |
| Тайлмапы Play: атлас, autotile, пути tileset | `tilemap_layer_painter.dart`, `tileWidth` в tileset | ✅ |
| Документация ограничений обновлена | `GAME_AUTHOR.md`, `KNOWN_LIMITATIONS.md` | ✅ |

**Критерий готовности:** автор открывает demo → Play → визуал = редактор, 60 FPS на среднем ПК.

**Проверка:** `python scripts/generate_wave0_demo_assets.py` → `scripts/run-wave0-regression.ps1` → открыть demo в редакторе.

---

## Волна 1 — Плагины v1 + заготовка 3D ✅

**Цель:** формальная система расширений; 3D как **плагин**, не в ядре.

| Задача | Результат | Статус |
|--------|-----------|--------|
| `lynx.plugin.json`, реестр, `LynxPluginHost` | `client/lib/features/plugins/` | ✅ |
| `extensions` в сцене (редактор + Rust) | `Scene.extensions`, export → Rust | ✅ |
| Пакет `plugins/lynx_3d` | `projects/platformer-demo-3d` | ✅ |
| UI в редакторе | «Плагины Lynx…», chips, панель 3D | ✅ |

**Критерий готовности:** проект с `"enabled": ["lynx.3d"]` открывается; сцена сохраняет `extensions.lynx.3d`; ядро не падает без нативной 3D-библиотеки.

**Проверка:** `scripts/run-wave1-regression.ps1` → открыть `projects/platformer-demo-3d`.

---

## Волна 2 — Godot-like рантайм ✅

**Цель:** несколько сцен и события без ECS.

| Задача | Результат | Статус |
|--------|-----------|--------|
| `SceneManager`: load / change / stack | `load_scene` / `push_scene` / `pop_scene` в Lua, `scene_take_pending_load` FFI | ✅ |
| Autoload из `project.json` | `autoloadSceneIds`, `scene_autoload_merge.dart` | ✅ |
| Input Map → действия | `input_map` в Rust, `action_*` в Lua | ✅ |
| Сигналы: `emit` / `on_signal` | `emit_signal`, `runtime::dispatch_scene_signals` | ✅ |
| `time_scale`, пауза | `scene_set_paused`, `scene_set_time_scale` FFI | ✅ |

**Критерий готовности:** demo с меню-сценой и уровнем, переход по кнопке.

**Проверка:** `python scripts/generate_wave0_demo_assets.py` → `scripts/run-wave2-regression.ps1` → Play в `projects/platformer-wave2` (Enter → уровень).

---

## Волна 3 — Export и Player ✅

**Цель:** «собрать игру» как у Godot Export.

| Задача | Результат | Статус |
|--------|-----------|--------|
| `main_player.dart` — Lynx Player | `lib/main_player.dart`, `standalonePlayer` | ✅ |
| Preset Windows: Player + `game_data` | ZIP itch.io, `bin/engine.dll` | ✅ |
| Preset Android: lynxpack + jniLibs | `lynx_game_data.lynxpack`, инструкция APK | ✅ |
| Preset Web: `flutter build web` + `game_data` | `web/game_data`, loader в Player | ✅ |

**Критерий готовности:** один проект → три артефакта без ручного копирования папок.

**Проверка:** `scripts/run-wave3-regression.ps1` → `scripts/export-player.ps1` → `Lynx/docs/EXPORT.md`

---

## Волна 4 — Кроссплатформенный паритет ✅

**Цель:** Android/iOS/Web не урезаны относительно Windows.

| Задача | Результат | Статус |
|--------|-----------|--------|
| CI: `cargo ndk` → `libengine.so` | `engine/scripts/build-ndk-only.ps1` | ✅ |
| iOS: xcframework + чеклист | `build-ios-xcframework.ps1`, `PLATFORM_QA.md` | ✅ |
| Web: паритет `WebSceneEngine` | `web_script_runtime.dart`, input map, `load_scene` | ✅ |
| Версии ядра | `engine_version_gate.dart`, `minNexusEngineVersion` | ✅ |

**Критерий готовности:** demo проходит QA на Win + Android + Chrome.

**Проверка:** `scripts/run-wave4-regression.ps1` → `docs/PLATFORM_QA.md`

---

## Волна 5 — Редактор Pro ✅ (v1)

**Цель:** удобство уровня «серьёзная 2D-студия».

| Итерация | Содержание | Статус |
|----------|------------|--------|
| 5a | AnimationPlayer → `animation_clips` | `animation_player_panel.dart`, inspector | ✅ |
| 5b | Визуальный редактор Behavior Tree | `behavior_tree_editor_dialog.dart` | ✅ |
| 5c | In-game UI (Flutter по JSON сцены) | слой `layer_ui`, `GameUiOverlay` | ✅ |
| 5d | Шаблоны проектов | `lynx_project_templates.dart`, Hub локально | ✅ |

**Проверка:** `scripts/run-wave5-regression.ps1` → инспектор объекта → AnimationPlayer / BT / UI кнопка.

---

## Волна 6 — Плагин 3D v1 ✅

**Цель:** первая **играбельная** 3D-сцена через плагин `lynx.3d`, без 3D в core.

Зависит от [PLUGIN_SYSTEM.md](PLUGIN_SYSTEM.md).

| Этап | Содержание | Статус |
|------|------------|--------|
| 6a | Контракт 3D + хук `lynx_3d::post_update_stub` (Rust) | ✅ |
| 6b | Редактор: orbit viewport (`Lynx3dEditorViewport`) | ✅ |
| 6c | Импорт GLB/GLTF → `assets/models/` + `.lynx3d.json` | ✅ |
| 6d | Play: wireframe overlay (`Game3dPlayOverlay`) | ✅ |
| 6e | AABB-гравитация на клиенте (пол комнаты) | ✅ |

**Проверка:** `scripts/run-wave6-regression.ps1` · проект `projects/platformer-demo-3d-room` · вкладка «3D» · Play overlay.

**Ограничения:** GLB без материалов/текстур (Lambert по цвету объекта); веб — упрощённый overlay.

---

## Волна 7 — Экосистема Hub + Cloud ✅

**Цель:** маркетплейс как у Asset Library Godot, через Lynx Hub и Launcher.

| Этап | Содержание | Статус |
|------|------------|--------|
| 7a | Контракт каталога `apiVersion: 1` | ✅ `ECOSYSTEM_CLOUD_HUB.md`, JSON |
| 7b | Launcher: загрузка + установка plugin/template | ✅ `lynx_marketplace.dart` |
| 7c | Hub: `marketplace-catalog.json` | ✅ |
| 7d | Cloud API billing/download | 🔲 волна 8b |

**Проверка:** Launcher → Lynx Cloud → установить `lynx.3d` в проект.

---

## Волна 8 — Cloud API маркетплейса ✅

| Этап | Содержание | Статус |
|------|------------|--------|
| 8a | `lynx-server`: catalog / claim / download | ✅ |
| 8b | Launcher + JWT (`lynx_cloud_marketplace.dart`) | ✅ |
| 8c | Архитектура **Lynx Core** (свой движок) | ✅ `LYNX_CORE_ARCHITECTURE.md`, `lynx-core/` |
| 8d | Billing платных пакетов | 🔲 |

**Проверка:** `scripts/run-wave8-regression.ps1` · `docs/CLOUD_API_WAVE8.md`

---

## Волна 10 — BT debug + UI layout ✅

BT overlay в Play, breakpoint/step, UI anchors 16:9/9:16 — `scripts/run-wave10-regression.ps1`

---

## Волна 9 — Редактор Pro v2 ✅

AnimationPlayer v2, key events, collision preview — **[EDITOR_GODOT_PARITY.md](EDITOR_GODOT_PARITY.md)** · `scripts/run-wave9-regression.ps1`

---

## Волны 10–14 — Универсальный движок

Детальный план: **[ROADMAP_TECH_FINISH.md](ROADMAP_TECH_FINISH.md)**.

Кратко — **[ENGINE_UNIVERSAL.md](ENGINE_UNIVERSAL.md)**:

| Волна | Фокус |
|-------|--------|
| 8 | Cloud API маркетплейса + лицензии |
| 9–10 | Редактор = Godot (animation v2, BT debug, UI layout) |
| 11 | Паритет Win/Android/iOS/Web (WASM) |
| 12–14 | `lynx_render` PBR, скелеты, terrain, Rapier3D |

---

## Зависимости между волнами

```
Волна 0 ──► Волна 1 (плагины)
    │
    ├──► Волна 2 (рантайм)
    │         │
    │         └──► Волна 3 (export)
    │                   │
    └───────────────────┴──► Волна 4 (паритет)
                              │
                              ├──► Волна 5 (редактор)
                              └──► Волна 6 (3D плагин)
                                        │
                                        ├──► Волна 7 (экосистема)
                                        └──► Волны 8–14 (универсальный движок)
```

---

## Ритм работы (рекомендация)

| Период | Действие |
|--------|----------|
| Спринт 2 нед. | 1 волна или половина волны |
| Конец спринта | Demo + тег `lynx-wave-N` |
| Перед волной 6 | Закрыть волну 4 на целевых платформах |

---

## Метрики «мы ближе к Godot»

| Метрика | Волна |
|---------|-------|
| Play = Editor | 0 |
| Плагины в проекте | 1 |
| Несколько сцен | 2 |
| Export в 3 платформы | 3 |
| Один demo на Win/Android/Web | 4 |
| 3D demo (плагин) | 6 |

---

## Дальнейший путь (2 продукта: Launcher + Engine)

Полная карта волн **15–32**: Launcher = портал (мессенджер, облако, ядра, аркада); Engine = редактор + runtime + export.

→ **[ROADMAP_WAVES_UNIFIED.md](ROADMAP_WAVES_UNIFIED.md)**
