# Lynx Core — волна 12 (3D v2)

**Crate:** `0.6.0-m6` (контракт M12a без bump API)  
**Плагин:** `lynx.3d` · capability `render.3d.native`

---

## 12a — Albedo texture (✅ контракт + CPU tint)

| Компонент | Путь |
|-----------|------|
| JSON `material.albedoTexture` | `scene3d.rs`, Flutter `lynx_3d_codec.dart` |
| PNG load | `asset/texture_rgba8.rs` (`image` crate) |
| Tint `base_color` | `render/forward3d.rs` → `Forward3DFrame` |

Пример в `extensions.lynx.3d`:

```json
"material": {
  "albedoTexture": "assets/textures/crate_albedo.png",
  "metallic": 0.15,
  "roughness": 0.55,
  "metallicRoughnessTexture": "assets/textures/crate_mr.png"
}
```

`metallicRoughnessTexture` — **зарезервировано** (пока scalar metallic/roughness в шейдере).

**Ограничение M12a:** tint по среднему RGB текстуры; **GPU sampling + UV** — 12b.

---

## 12b — GPU albedo (✅)

| Компонент | Путь |
|-----------|------|
| UV в вершине | `Vertex3d.uv`, `Mesh3d.uvs`, GLB `TEXCOORD_0` |
| Шейдер | `shaders/forward3d.hlsl` — `albedoMap` @ `t1`, `useAlbedo` в ObjectCB |
| D3D12 | per-mesh VB/IB cache, SRV heap, `scripts/compile-shaders.ps1` |
| Draw | `albedo_image` → GPU texture; `lynx-m3-demo` / PAL forward |

```powershell
Lynx/lynx-core/scripts/compile-shaders.ps1
cargo run --features pal_win_d3d12 --bin lynx-m3-demo
```

---

## 12c — Shadow PCF + 2-cascade (✅)

| Компонент | Поведение |
|-----------|-----------|
| PCF | 3×3 фильтр shadow map (M3 заявлял PCF — теперь в `forward3d.hlsl`) |
| Bias / penumbra | `ShadowSettings` в `Forward3DFrame` → `shadowParams` CB |
| Cascade | 2× 2048²: tight (42% extent) + full room; blend по дистанции камеры |
| GPU | `shadowMap` @ t0, `shadowMapC1` @ t2; два shadow pass |

```rust
// forward3d.rs
ShadowSettings {
  texel_size: 1.0 / 2048.0,
  depth_bias: 0.002,
  penumbra: 0.35,
  cascade_split_distance: 10.0,
  enable_cascade: true,
}
```

Отключить cascade: `enable_cascade: false` (одна матрица, только PCF).

---

## Регрессия

```powershell
Lynx/scripts/run-m12-regression.ps1
Lynx/scripts/run-all-regression.ps1 -Tier quick
```
