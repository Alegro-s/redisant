# Lynx 3D Engine (целевой модуль)

Текущий `lynx.3d` (волна 6) — **preview**: GLB → затенённые треугольники на Canvas.

## Целевое состояние (волны 12–14)

### Crates (Rust)

| Crate | Ответственность |
|-------|------------------|
| `lynx_render` | wgpu, GLTF, PBR, lights, shadows, skinning |
| `lynx_physics3d` | Rapier: rigid, collider, character controller |
| `engine` | FFI: `lynx_render_frame`, `lynx_physics3d_step` |

### Flutter

- Текстура RGBA с GPU каждый кадр **или** `TextureWidget` / platform view
- Редактор: тот же viewport, без Canvas tri-fill
- Export: `lynx_render.dll` / `.so` в Player

### Контракт сцены (без ломки v3)

`extensions.lynx.3d` + `properties.lynx.3d` — как сейчас; добавятся:

```json
{
  "material": { "baseColor": "#fff", "metallic": 0, "roughness": 0.8 },
  "skinnedMesh": { "skeleton": "...", "animation": "idle" },
  "terrain": { "heightmap": "assets/terrain/hm.png", "size": [64, 8, 64] }
}
```

### Поэтапно

1. **12a** — wgpu clear + mesh + 1 directional light  
2. **12b** — PBR albedo/metallic/roughness из GLTF  
3. **12c** — shadow map 2048  
4. **13a** — skinning + animation clip  
5. **13b** — terrain chunk mesh  
6. **14** — Rapier3D + broadphase с 2D (hybrid проекты)

До волны 12: улучшать Canvas (текстуры из GLTF, UV) — опционально в **7.3d-preview**.

Полный паритет с Godot 3D — **не цель v1**; цель — **играбельный 3D** для типовых indie-сцен.
