# Lynx product architecture

## Два продукта

| Продукт | Установка | Назначение |
|---------|-----------|------------|
| **Lynx Launcher** | `Lynx-Launcher.msi` | Портал: вход, мессенджер, облако, новости, магазин, проекты, **выбор и установка ядра**, **запуск Lynx Engine** |
| **Lynx Engine** | `.lynxengine` (из Launcher) | **Всё для игр:** редактор, Play, экспорт, рантайм, инструменты, сборка APK/EXE |

**Launcher не содержит редактора и не грузит `engine.dll` для редактирования.**  
**Редактор, Play, Export — только внутри процесса Lynx Engine.**

Дорожная карта волн: [ROADMAP_WAVES_UNIFIED.md](ROADMAP_WAVES_UNIFIED.md)

---

## Lynx Launcher (портал)

### Содержимое MSI (без движка)

- Учётная запись, настройки, мессенджер
- Новости, маркетплейс / Lynx Cloud
- Мои проекты (локальные + облачные)
- Импорт `.lynxproject` / ZIP
- **Центр ядер движка** — список версий, скачать `.lynxengine`, импорт файла
- Шаблоны проектов (копируются при создании; работа — в Engine)
- SDK/client для Android-сборки (вспомогательно, вызывается из Engine)
- **Не входит:** `engine.dll`, холст сцены, Play, редактор

### Поток «начать работу»

1. Пользователь выбирает проект в Launcher.
2. Проверка `minLynxCoreVersion` / `.lynx/engine_lock.json`.
3. Если ядро не установлено → скачать нужный `.lynxengine`.
4. Launcher запускает **Lynx Engine** (отдельный процесс) с аргументами проекта и версии ядра.
5. Пользователь работает **только в окне Engine** до выхода.

### Web

Launcher = Hub (`lynx-hub.ru`): вход, проекты, аркада, новости.  
Engine = отдельный маршрут `/engine` (WASM + UI), открывается из Launcher.

---

## Lynx Engine (движок + студия)

### Содержимое `.lynxengine`

Устанавливается в `%LOCALAPPDATA%\Lynx\engines\<version>\<platform>\`:

| Компонент | Описание |
|-----------|----------|
| `engine.dll` / `libengine.so` | Rust runtime (Lynx Core / Legacy) |
| `LynxEngine.exe` (цель волны 16) | UI shell: редактор + Play + export |
| `shaders/`, manifests | Рендер, версия Core |

### Внутри Engine (не отдельные продукты для пользователя)

| Модуль | Было |
|--------|------|
| Редактор сцены | `main_editor.dart` / `EngineMainPage` |
| Play / предпросмотр | embedded + fullscreen |
| Экспорт Win/APK/Web | `lynx_export_sheet`, build scripts |
| Player template | `main_player.dart` → артефакт экспорта |
| Инструменты TIC-стиля | спрайт, карта, звук (режим Консоль) |
| Плагины 3D, BT, Blueprint | как сейчас |

### Экспорт игры (для игроков, не Lynx)

```
MyGame/
  client.exe          # Lynx Player (из шаблона Engine)
  bin/engine.dll      # из bound Engine version
  game_data/
```

Player — **результат экспорта**, не часть Launcher MSI.

---

## `.lynxengine` format

```
[8 bytes]  magic "LYNXENG1"
[4 bytes]  header schema (1)
[4 bytes]  manifest JSON length
[N bytes]  manifest JSON (version, platform, lynxCoreVersion, payloadSha256, …)
[M bytes]  AES-256-GCM encrypted zip (nonce + ciphertext + tag)
```

Inner zip: native library + Engine UI shell + optional `shaders/` + `inner_manifest.json`.

Pack/unpack (dev):

```powershell
python pack_lynx_engine.py --version 0.14.0 -o dist\engine_0.14.0_windows.lynxengine
python unpack_lynx_engine.py dist\engine_0.14.0_windows.lynxengine -o dist\extracted
```

Decryption key derivation: `LynxEnginePack:v1:…` (Launcher + Engine shell).

---

## Project creation flow

### Local project

1. User picks template in **Launcher**.
2. **Gate:** if Lynx Engine not installed → version picker + download `.lynxengine`.
3. Write `project.json`: `minLynxCoreVersion`, `studioEngineBoundVersion`.
4. Write `.lynx/engine_lock.json` (`format: lynx_engine_lock`).
5. **Launcher spawns Lynx Engine** with project path.

### Cloud project

1. User signed in (Launcher).
2. Pick engine version; install if missing.
3. POST `/projects` with `lynx_engine_version`.
4. **Engine** loads cloud project; version enforced via lock.

---

## Visual scripting (Blueprint)

Inside **Engine** only:

- LynxGraph → LynxScript via `lynx_graph_compiler.dart`
- Runtime: Lynx Core VM / Lua adapter

---

## `.lynxproject` / `.lynxcart`

| Формат | Кто создаёт | Кто потребляет |
|--------|-------------|----------------|
| `.lynxproject` | Engine export / Hub | Launcher import → Engine open |
| `.lynxcart` (волна 17) | Engine pack | Launcher Arcade play / Engine Play-only |

---

## Build commands

Launcher MSI (без движка):

```powershell
cd Lynx\scripts
.\build-lynx-launcher-msi.ps1
```

Engine pack:

```powershell
cd Lynx\scripts
.\publish_lynx_engine_release.ps1 -Version 0.15.0
```

---

## Legacy naming

User-facing: **Lynx Launcher**, **Lynx Engine**.  
Internal: `nexus_engine`, `minNexusEngineVersion` — migration in progress.
