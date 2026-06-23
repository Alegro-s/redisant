# Lynx Core M2 — 2D Sprite Batch + Legacy FFI

**Версия crate:** `0.2.0-m2`  
**Feature:** `pal_win_d3d12` (Windows: D3D12 + batch draw)

M2 добавляет **CPU 2D batch** в Core и **делегирование из Legacy `engine/`** через FFI. Flutter по-прежнему рисует Play через Skia; нативный batch — задел под Windows Player / Core viewport.

---

## Компоненты

| Модуль | Путь |
|--------|------|
| `SpriteBatch2D` | `lynx-core/src/render/batch2d.rs` |
| D3D12 flush | `lynx-core/src/pal/win_d3d12_batch.rs` |
| C FFI | `lynx-core/src/ffi.rs` |
| Заполнение из сцены | `engine/src/batch_sync.rs` |
| Демо | `lynx-m2-demo` |

### Batch API (Rust)

- `SpriteBatch2D::push_sprite` / `push_center_rect`
- `set_viewport(w, h)` — пиксели → NDC
- `build_vertices()` — сортировка по layer/order/texture, 6 вершин на квад
- `scene_fill_batch2d(scene, batch, vw, vh)` в `engine` — видимые entity → batch (как `game_world_painter.dart`)

### FFI (`engine.dll`)

| Функция | Назначение |
|---------|------------|
| `lynx_core_api_version` | `CORE_API_VERSION` |
| `lynx_core_version_string` | `"0.2.0-m2"` |
| `batch2d_create` / `destroy` / `clear` / `set_viewport` | Управление batch |
| `batch2d_push` | Один спрайт (`LynxBatch2DSpriteC`) |
| `batch2d_len` / `batch2d_build_vertex_count` | Диагностика |
| `scene_fill_batch2d` | Legacy Scene → batch |

---

## Сборка и демо

```powershell
cd Lynx/lynx-core
cargo run --features pal_win_d3d12 --bin lynx-m2-demo
cargo run --features pal_win_d3d12 --bin lynx-m2-demo -- --frames 2

cd Lynx/engine
cargo build --release
cargo test
```

Ожидаемый вывод CI:

```text
Lynx Core M2 OK: backend=D3D12+Batch2D, frames=2
```

Шейдеры: `shaders/batch2d.hlsl` → `assets/shaders/*.cso` (fxc `vs_5_0` / `ps_5_0`).

---

## Регрессия

```powershell
Lynx/scripts/run-m2-regression.ps1
```

---

## Следующий этап (M3)

3D forward PBR в Core; плагин `lynx.3d` на тех же JSON.

См. [LYNX_CORE_ARCHITECTURE.md](LYNX_CORE_ARCHITECTURE.md).
