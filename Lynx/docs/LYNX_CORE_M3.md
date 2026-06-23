# Lynx Core M3 — Forward 3D PBR-lite

**Версия crate (M3):** `0.3.1-m3` · текущий crate: `0.4.0-m4` (M3+M4 в одной ветке)  
**Feature:** `pal_win_d3d12`  
**API:** `CORE_API_VERSION = 2` (M3) → `3` (M4)

M3 — нативный **forward 3D** в Core: directional light + ambient, **shadow map 2048**, depth buffer, материалы metallic/roughness. Контракт сцены — тот же JSON, что у плагина **`lynx.3d`** (`extensions.lynx.3d`).

---

## Компоненты

| Модуль | Путь |
|--------|------|
| Парсинг `lynx.3d` | `lynx-core/src/scene3d.rs` |
| Forward frame | `lynx-core/src/render/forward3d.rs` |
| Меши / GLB (мин.) | `render/mesh3d.rs`, `asset/glb_minimal.rs` |
| D3D12 2-pass shadow | `pal/win_d3d12_forward3d.rs` |
| Шейдеры | `shaders/forward3d.hlsl` → `assets/shaders/*.cso` (`scripts/compile-shaders.ps1`) |
| M12b albedo | `t1` albedo + UV в вершине; per-mesh VB, SRV heap |
| Демо | `lynx-m3-demo` |

### JSON (без ломки v3)

Совместим с Flutter `lynx_3d_codec.dart`: `world`, `camera`, `room`, `objects[]`, `transform`, `halfExtents`, `color`, `material.metallic/roughness`, `meshPath`.

Эталон: `lynx-core/testdata/lynx3d_room_snippet.json`, проект `projects/platformer-demo-3d-room/` (волна 14: physics + `core_forward_d3d12`).

Полная сцена v3: `parse_extension_from_scene_json` или `--json` с `formatVersion` + `extensions`.

### Legacy `engine`

- `plugins/lynx_3d.rs` — `post_update_stub` парсит extension через Core.
- FFI: `lynx3d_parse_extension_object_count`, `scene_lynx3d_object_count`, `forward3d_frame_draw_count`.

Play в Launcher по-прежнему рисует **Canvas preview**; нативный forward — `lynx-m3-demo` и будущий Player viewport.

---

## Shadow map 2k

1. **Shadow pass:** ortho light VP → R32_FLOAT 2048×2048, depth-only PSO (`VSShadow` / `PSShadow`).
2. **Main pass:** forward PBR-lite + **3×3 PCF** + optional **2-cascade** (M12c).

Комната (floor/walls) не отбрасывает тени; объекты сцены — `cast_shadow: true`.

---

## GLB mesh

`Forward3DFrame::from_lynx3d_scene_with_assets(..., project_root)` загружает `meshPath` через `load_glb` (POSITION, NORMAL, indices). Без файла — unit cube с `halfExtents`.

---

## Сборка и демо

```powershell
cd Lynx/lynx-core
cargo run --features pal_win_d3d12 --bin lynx-m3-demo
cargo run --features pal_win_d3d12 --bin lynx-m3-demo -- --frames 2
cargo run --features pal_win_d3d12 --bin lynx-m3-demo -- --json ..\projects\platformer-demo-3d-room\scenes\main.json --project ..\projects\platformer-demo-3d-room
```

Ожидаемый вывод CI:

```text
Lynx Core M3 OK: backend=D3D12+Forward3D, frames=2, objects=1, draws=6
```

(`draws` = room quads + objects)

---

## Регрессия

```powershell
Lynx/scripts/run-m3-regression.ps1
```

---

## Не в M3 (следующие этапы)

- Текстуры GLTF albedo/normal в GPU (волна 12b)
- Skinning, terrain, Rapier3D (волны 13–14)

См. [LYNX_3D_ENGINE.md](LYNX_3D_ENGINE.md), [ROADMAP_TECH_FINISH.md](ROADMAP_TECH_FINISH.md).
