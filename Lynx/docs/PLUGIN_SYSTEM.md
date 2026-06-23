# Система плагинов Lynx

Расширения **не вшиваются в ядро 2D**. Плагин объявляет возможности (`capabilities`), данные в `project.json` и блоки `extensions` в сцене/объектах.

## Версии API

| Поле | Значение |
|------|----------|
| `lynxPlugins.apiVersion` в проекте | `1` |
| `apiVersion` в `lynx.plugin.json` | `1` |

При несовместимости редактор показывает предупреждение и не грузит плагин.

## Манифест плагина (`lynx.plugin.json`)

```json
{
  "id": "lynx.3d",
  "name": "Lynx 3D",
  "version": "0.1.0",
  "apiVersion": 1,
  "description": "3D сцены, камера и объекты поверх Lynx 2D",
  "capabilities": [
    "scene.3d",
    "render.3d",
    "physics.3d",
    "editor.viewport.3d"
  ],
  "engine": {
    "optionalNativeLib": "lynx_plugin_3d",
    "sceneExtensionKey": "lynx.3d",
    "objectPropertyKey": "lynx.3d"
  },
  "client": {
    "builtinId": "lynx.3d"
  }
}
```

### Capabilities (v1)

| ID | Назначение |
|----|------------|
| `scene.3d` | Расширение сцены (`extensions.lynx.3d`) |
| `render.3d` | Отдельный проход отрисовки в Play |
| `physics.3d` | 3D-коллизии (будущий native) |
| `editor.viewport.3d` | Панель/режим редактора |
| `export.hook` | Участие в export preset |
| `script.hook` | Доп. API в Lua (будущее) |

## Проект (`project.json`)

```json
{
  "lynxPlugins": {
    "apiVersion": 1,
    "enabled": ["lynx.3d"],
    "config": {
      "lynx.3d": {
        "defaultCamera": "perspective",
        "unitsPerMeter": 1.0
      }
    }
  },
  "projectMode": "3d"
}
```

- `projectMode`: `2d` (по умолчанию) | `3d` | `hybrid`
- `enabled` — список `id` плагинов

## Сцена (`scenes/*.json`)

Плагины **не меняют** `formatVersion: 3`. Данные — в `extensions`:

```json
{
  "formatVersion": 3,
  "extensions": {
    "lynx.3d": {
      "active": true,
      "world": {
        "ambientColor": "#404050",
        "gravity": [0, -9.81, 0]
      },
      "camera": {
        "type": "perspective",
        "fovY": 60,
        "near": 0.1,
        "far": 500
      }
    }
  }
}
```

## Объект (`objects[].properties`)

```json
{
  "properties": {
    "lynx.3d": {
      "mesh": "assets/models/crate.glb",
      "transform": {
        "position": [0, 1, 0],
        "rotationEuler": [0, 45, 0],
        "scale": [1, 1, 1]
      }
    }
  }
}
```

## Где что живёт в коде

| Слой | Каталог |
|------|---------|
| Контракт, реестр, host | `client/lib/features/plugins/` |
| Встроенный 3D (волна 6) | `client/lib/features/plugins/lynx_3d/` |
| Builtin регистрация | `client/.../plugins/builtin/lynx_3d_plugin.dart` |
| Манифест пакета | `Lynx/plugins/lynx_3d/` |
| Реестр в Rust | `engine/src/plugins/` |
| Поле `extensions` | `Scene` в `lib.rs` и `engine_models.dart` |

## Жизненный цикл (клиент)

1. `LynxPluginRegistry.ensureInitialized()` — builtin (`lynx.3d`).
2. Открытие проекта → `LynxPluginHost.openProject` + скан `{projectRoot}/plugins/*/lynx.plugin.json`.
3. Загрузка сцены → `applySceneExtensions` подмешивает блоки в `Scene.extensions`.
4. Экспорт Play → `mergeSceneExport` → `extensions` + `enabled_plugins` в JSON для Rust.
5. Редактор: **⋮ → «Плагины Lynx…»**, chips под AppBar, панель **«Плагины сцены»** (если `lynx.3d` включён).

## Native-плагины (будущее)

Опциональная библиотека `lynx_plugin_3d.dll` / `.so`:

- те же `capabilities`, что в манифесте;
- FFI-хуки `lynx_plugin_register` (волна 6);
- ядро **работает без** DLL — 3D только в данных и Flutter-preview.

## Добавление своего плагина

1. Создать папку `my_game/plugins/my_plugin/lynx.plugin.json`.
2. Реализовать `LynxClientPlugin` в Dart (см. `lynx_plugin_contract.dart`) **или** подключить пакет с `builtinId` в реестр студии.
3. Включить `id` в `project.json` → `lynxPlugins.enabled`.
4. Писать данные только в `extensions.<pluginId>` и `properties.<pluginId>`.

## Плагин 3D — текущий статус

**Волна 1:** манифест, реестр, stub, поля в проекте/сцене.  
**Волна 6:** viewport, glTF, native физика — см. [ROADMAP_WAVES.md](ROADMAP_WAVES.md).
