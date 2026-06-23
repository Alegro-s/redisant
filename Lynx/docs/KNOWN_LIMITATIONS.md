# Lynx — состояние платформы

Актуально после **волн 11–14**, **Q3**. Детали: [ROADMAP_TECH_FINISH.md](ROADMAP_TECH_FINISH.md), [PLATFORM_QA.md](PLATFORM_QA.md).

## Lynx Core (`lynx-core/`)

| Область | Состояние |
|---------|-----------|
| M3 forward 3D | D3D12 PBR-lite + shadow 2k + GLB mesh cache |
| M12 | GPU albedo/UV, PCF, 2-cascade shadows |
| M13 | CPU skinning + animation clips; terrain heightmap + LOD |
| M14a | 3D AABB physics (`physics3d_world_*` FFI) |
| Q3 Player (Win) | `windows3dRuntime: core_forward_d3d12` — D3D12 child viewport |
| 14b culling | CPU frustum + Hi-Z (room back wall); GPU hi-z readback — нет |
| WASM | PAL stub; batch2d/physics3d Play — нативный Windows/Android |

## Игровой движок (`engine/`)

| Область | Состояние |
|---------|-----------|
| Рендер 2D Play | Flutter; Rust — симуляция + JSON |
| 3D physics FFI | Реэкспорт `physics3d_*` из Lynx Core |
| Lua / LynxScript | `legacy_lua` по умолчанию |
| BT / анимация / тайлмапы | Play + редактор |

## Клиент

| Область | Состояние |
|---------|-----------|
| 3D Play | Canvas preview или Core viewport (Windows); Core physics при `engine.dll` |
| Веб | `web_scene_engine`; 3D overlay + упрощённая Dart-физика |
| Export | Windows/Web/Android + `windows3dRuntime` / `webRuntime` в meta |

## Регрессия

```powershell
Lynx/scripts/run-all-regression.ps1 -Tier quick
Lynx/scripts/run-m14-regression.ps1
```
