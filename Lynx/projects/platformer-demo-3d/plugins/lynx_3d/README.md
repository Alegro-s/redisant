# Lynx 3D (плагин)

Официальный плагин для 3D-игр на платформе Lynx. **Не входит в ядро 2D.**

## Включение

В `project.json`:

```json
{
  "projectMode": "3d",
  "lynxPlugins": {
    "apiVersion": 1,
    "enabled": ["lynx.3d"],
    "config": {
      "lynx.3d": {
        "defaultCamera": "perspective"
      }
    }
  }
}
```

Скопируйте эту папку в `{ваш_проект}/plugins/lynx_3d/` или используйте встроенный `builtinId` в студии.

## Дорожная карта

| Волна | Содержание |
|-------|------------|
| 1 | Манифест, `extensions`, stub (текущее) |
| 6 | Viewport 3D, glTF, `lynx_plugin_3d` native |

См. [docs/PLUGIN_SYSTEM.md](../docs/PLUGIN_SYSTEM.md) и [docs/ROADMAP_WAVES.md](../docs/ROADMAP_WAVES.md).
