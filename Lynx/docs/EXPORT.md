# Lynx — экспорт игры (волна 3)

Цель: один проект → артефакты для **Windows**, **Web** и **Android** без ручного копирования папок.

Точка входа Player (только игра, без редактора):

```bash
cd Lynx/client
flutter run -t lib/main_player.dart
```

Рядом с исполняемым файлом должна быть папка **`game_data/`** с `project.json` и `scenes/`.

---

## Редактор

Меню сцены → **⋮** → **Экспорт игры (Player)…**

| Пресет | Содержимое |
|--------|------------|
| **Windows** | `windows/game_data`, `windows/bin`, ZIP для itch.io |
| **Web** | `web/game_data` + копия в `client/web/game_data` для сборки |
| **Android** | `lynx_game_data.lynxpack`, подсказка jniLibs, инструкция APK |
| **Только game_data** | копия проекта |

---

## Windows (itch.io)

1. Экспорт **Windows** из редактора.
2. Соберите Player:

```powershell
cd Lynx/client
flutter build windows -t lib/main_player.dart --release
```

3. Скопируйте из `build/windows/x64/runner/Release/` в папку экспорта `windows/`:
   - `client.exe` (и соседние DLL Flutter)
   - уже лежат `game_data/` и `bin/engine.dll`

4. Загрузите ZIP (`*_windows.zip`) на itch.io.

### Windows 3D (Q3)

В `project.json` (опционально):

```json
"windows3dRuntime": "core_forward_d3d12"
```

| `windows3dRuntime` | Назначение |
|--------------------|------------|
| `canvas_preview` | Flutter Canvas overlay (по умолчанию) |
| `core_forward_d3d12` | D3D12 Forward3D child HWND в Player (Windows) |

Поле попадает в `windows/lynx_export.json` при экспорте. Требует `engine.dll`, собранный с `pal_win_d3d12` (см. `engine/Cargo.toml`).

---

## Web

1. Экспорт **Web** (заполнит `client/web/game_data/`).
2. В `project.json` (волна 11b):

```json
"webRuntime": "web_scene_engine"
```

| `webRuntime` | Назначение |
|--------------|------------|
| `web_scene_engine` | Player на Dart ([WebSceneEngine](../client/lib/features/engine/runtime/web_scene_engine.dart)) |
| `wasm_core_stub` | зарезервировано для WASM `lynx-core`; пока не используйте в продакшене |

Поле попадает в `web/lynx_export.json` при экспорте.

3. Сборка:

```bash
cd Lynx/client
flutter build web -t lib/main_player.dart --release
```

3. Хостинг содержимого `build/web/` (статика + `game_data/`).

---

## Android

1. Экспорт **Android** → `lynx_game_data.lynxpack`.
2. Скопируйте в `client/assets/` и добавьте в `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/lynx_game_data.lynxpack
```

3. `libengine.so` в `android/app/src/main/jniLibs/arm64-v8a/` (см. `engine/scripts/build-apk.ps1`).
4. `flutter build apk -t lib/main_player.dart --release`

---

## Автоматизация

```powershell
Lynx/scripts/export-player.ps1 -Project projects/platformer-wave2 -Preset all
Lynx/scripts/run-wave11-regression.ps1
```

---

## Переменные сборки

| Define | Назначение |
|--------|------------|
| `LYNX_GAME_DATA` | Абсолютный путь к проекту |
| `LYNX_ENGINE_LIB` | Путь к engine.dll / libengine.so |
