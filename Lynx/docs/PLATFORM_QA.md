# Lynx — QA кроссплатформы (волна 4 → 11)

Критерий **волны 11**: demo **platformer-wave2** проходит на **четырёх** платформах без «только Windows».

| Платформа | Runtime | Скрипты / BT | Версии |
|-----------|---------|--------------|--------|
| **Windows** | `engine.dll` + Lynx Core | Lua (legacy) + LynxScript | `minNexusEngineVersion` + `minLynxCoreVersion` |
| **Android** | `libengine.so` jniLibs | то же | то же |
| **iOS** | `engine.xcframework` | то же | то же |
| **Web (Chrome)** | `WebSceneEngine` | упрощённый Lua-подмножество | проверка версий **пропускается**; `webRuntime` в export |

Автоматическая регрессия: `scripts/run-wave11-regression.ps1`.

---

## Матрица прогона (11a)

| ID | Windows | Android | iOS | Web |
|----|---------|---------|-----|-----|
| Регрессия CI | `run-wave11-regression.ps1` | — | — | Flutter tests |
| Demo | `platformer-wave2` Play | APK Player + pack | TestFlight чеклист | `export-player.ps1 -Preset web` |
| Touch | клавиатура + геймпад feeder | on-screen кнопки Player | то же | клавиатура |
| Меню → main | Enter / Space | touch confirm | то же | Enter / Space |

---

## Windows

| Шаг | Команда / действие |
|-----|-------------------|
| Регрессия | `scripts/run-wave11-regression.ps1` |
| Сборка engine | `cd engine && cargo build --release` |
| Play в редакторе | `projects/platformer-wave2` → Play |
| Player | `flutter run -t lib/main_player.dart` + `game_data/` |
| Версии | Hub показывает `NEXUS … · Core 0.6.0-m6 (API 4)` при установленном DLL |

**Q3 — Core 3D viewport в Player:**

```json
"windows3dRuntime": "core_forward_d3d12"
```

| Значение | Поведение |
|----------|-----------|
| `canvas_preview` | **по умолчанию** — `Game3dPlayOverlay` (Canvas) |
| `core_forward_d3d12` | child HWND + D3D12 Forward3D (`lynx_viewport_*` FFI) |

Экспорт Windows кладёт поле в `lynx_export.json`. Регрессия: `scripts/run-q3-regression.ps1`.

---

## Android (Rust + Player)

| Шаг | Команда |
|-----|---------|
| NDK → jniLibs | `engine/scripts/build-ndk-only.ps1` |
| Экспорт lynxpack | Редактор → Экспорт → Android |
| APK Player | `engine/scripts/build-apk.ps1` |

**11c:** виртуальные кнопки Player (`game_touch_controls.dart`), переход menu → main, офлайн без падений.

---

## Web (Chrome) — 11b

| Шаг | Команда |
|-----|---------|
| Экспорт Web | `scripts/export-player.ps1 -Preset web` |
| Сборка | `cd client && flutter build web -t lib/main_player.dart` |
| Хостинг | статика из `build/web/` |

В `project.json`:

```json
"webRuntime": "web_scene_engine"
```

| Значение | Поведение |
|----------|-----------|
| `web_scene_engine` | **по умолчанию** — физика, input map, `load_scene`, UV анимации |
| `wasm_core_stub` | зарезервировано; Player вернёт ошибку до подключения WASM Core |

`lynx_export.json` (папка `web/`) дублирует `webRuntime` для CI/хостинга.

Полный Lua/BT — только с нативным Rust (Windows/Android/iOS).

**M6:** `cargo build -p lynx-core --target wasm32-unknown-unknown` — smoke в `run-wave11-regression.ps1`.

---

## iOS (чеклист)

1. macOS + Xcode  
2. `engine/scripts/build-ios-xcframework.ps1`  
3. Подключить `engine.xcframework` в Runner  
4. `flutter build ios -t lib/main_player.dart`  
5. TestFlight — те же шаги, что Android (touch, menu → main)

---

## Версии ядра (11d)

В `project.json`:

```json
"minNexusEngineVersion": "0.1.0",
"minLynxCoreVersion": "0.6.0-m6"
```

| Поле | Что проверяется |
|------|-----------------|
| `minNexusEngineVersion` | метка релиза из Hub / кэша (`engine.dll` пакет) |
| `minLynxCoreVersion` | semver внутри библиотеки (`lynx_core_version_string`, API 4) |

На **веб** проверки нет (нет нативной DLL). Hub каталог: `hub/public/content/hub-content.json` → `engineCores` (в т.ч. `0.6.0-m6`).

Player без Lua: `cargo build -p engine --no-default-features`.

---

## Touch + gamepad (11c)

| Платформа | Механизм |
|-----------|----------|
| Desktop | `nexus_gamepad_feeder.dart` → `scene_set_gamepad` |
| Mobile Player | `GameHoldButton` overlay |
| Web | клавиатура + named keys в `WebSceneEngine` |

Ручной QA: `projects/platformer-wave2` на устройстве/emulator.
