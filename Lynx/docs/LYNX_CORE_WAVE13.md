# Lynx Core — волна 13 (скелеты + terrain)

**Crate:** `0.6.0-m6`  
**Плагин:** `lynx.3d` · capability `render.3d.native`

---

## 13a — GLTF skinning + animation clips (✅ CPU)

| Компонент | Путь |
|-----------|------|
| GLB skin + clips | `asset/glb_skin.rs` — `load_glb_skinned`, `SkinnedGlb::mesh_at` |
| CPU skin | `skin_mesh` — palette `global * inverseBind` |
| Forward3D | `forward3d.rs` — `CachedGlb::Skinned`, clip/time per object |
| JSON | `animationClip`, `animationTime` — `scene3d.rs`, `lynx_3d_codec.dart` |
| Math | `Mat4::from_quat`, `transform_point` |

Пример объекта:

```json
{
  "id": "hero",
  "mesh": "assets/hero_skinned.glb",
  "animationClip": "walk",
  "animationTime": 0.35
}
```

**Ограничение M13a:** skinning на **CPU** перед draw; GPU skinning — позже. Без `JOINTS_0`/`WEIGHTS_0`/`skin` — fallback на `load_glb` (статический меш).

---

## 13b — Terrain heightmap + LOD (✅ CPU)

| Компонент | Путь |
|-----------|------|
| Heightmap → mesh | `render/terrain_mesh.rs` |
| Forward3D draw | `forward3d.rs` — `terrain_draw`, LOD по дистанции камеры |
| JSON | `terrain` в `extensions.lynx.3d` — `scene3d.rs`, `lynx_3d_codec.dart` |

```json
"terrain": {
  "heightmap": "assets/terrain/hm.png",
  "size": [64, 8, 64],
  "center": [0, 0, 0],
  "segments": 32,
  "maxLod": 2,
  "lodSplitDistance": 12
}
```

- Высота из **R** канала PNG (0…255 → 0…1), билинейная выборка.
- **LOD:** `segments >> lod`, `lod = floor(dist / lodSplitDistance)` capped `maxLod`.
- Меш в локальных координатах центрирован на `center`; рисуется **до** room.

**Ограничение:** один terrain на сцену; clipmap / streaming — позже.

---

## Регрессия

```powershell
Lynx/scripts/run-m13-regression.ps1
Lynx/scripts/run-all-regression.ps1 -Tier quick
```
