# Lynx Core — волна 14 (3D physics)

**Crate:** `0.6.0-m6`  
**Плагин:** `lynx.3d` · capability `physics.3d`

---

## 14a — AABB colliders + rigid body (✅)

| Компонент | Путь |
|-----------|------|
| Solver | `physics/physics3d.rs` — гравитация, static planes (room), dynamic AABB |
| Контракт | `objects[].physics` — `bodyType`, `restitution`, `friction` |
| FFI | `physics3d_world_*` в `ffi.rs` → `engine.dll` |
| Play | `lynx3d_physics_io.dart` + `Game3dPlayOverlay` |

Пример объекта:

```json
{
  "id": "crate",
  "halfExtents": [0.5, 0.5, 0.5],
  "transform": { "position": [0, 3, 0] },
  "physics": {
    "bodyType": "dynamic",
    "restitution": 0.15,
    "friction": 0.55
  }
}
```

`bodyType: "static"` — коллайдер без интеграции. Комната `room` даёт 6 плоскостей-стен.

**Без Rapier** — свой deterministic solver (фиксированный шаг в Play ~1/60 с).

---

## 14b — Frustum + CPU Hi-Z (✅)

| Компонент | Путь |
|-----------|------|
| Frustum | `math.rs` — `Frustum::from_view_proj`, `Aabb3` |
| Hi-Z | `render/cull3d.rs` — 64×64 distance buffer, occluder = задняя стена `room` |
| Сцена | `world.culling` — `frustum`, `hiZ`, `hiZSize` |
| Forward3D | `forward3d.rs` — `CullStats` в `Forward3DFrame` |

```json
"world": {
  "culling": { "frustum": true, "hiZ": true, "hiZSize": 64 }
}
```

Объекты вне frustum или за Hi-Z occluder не попадают в `draws` (CPU, без GPU readback).

---

## Demo (Windows)

Проект `projects/platformer-demo-3d-room/`:

- комната `room` + PBR `material` на crate;
- `physics.bodyType: dynamic` — Core solver в Play (`Game3dPlayOverlay`);
- `windows3dRuntime: core_forward_d3d12` — Q3 viewport в Player.

```powershell
python Lynx/scripts/generate_wave0_demo_assets.py   # crate.glb
cd Lynx/client && flutter run -d windows            # Play → crate падает на пол
```

Walk cycle + albedo texture — отдельный ассет (критерий полной волны 14, см. ROADMAP).

---

## Регрессия

```powershell
Lynx/scripts/run-m14-regression.ps1
Lynx/scripts/run-all-regression.ps1 -Tier quick
```
