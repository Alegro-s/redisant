# Lynx Core Q3 — Windows Player viewport

**Блок F Q3:** нативный Forward3D в Player (Windows), пресет экспорта.

---

## Контракт `project.json`

```json
"windows3dRuntime": "core_forward_d3d12"
```

| Значение | Player |
|----------|--------|
| `canvas_preview` | Flutter `Game3dPlayOverlay` (по умолчанию) |
| `core_forward_d3d12` | D3D12 child HWND + `lynx_viewport_*` FFI |

Поле дублируется в `playBootstrap['lynx3d']['windows3dRuntime']` и в `windows/lynx_export.json`.

---

## FFI (`engine.dll`)

| Символ | Назначение |
|--------|------------|
| `lynx_viewport_available` | 1 если сборка с `pal_win_d3d12` |
| `lynx_viewport_create` | child HWND + D3D12 swapchain |
| `lynx_viewport_resize` | resize swapchain |
| `lynx_viewport_present_lynx3d` | JSON `lynx.3d` → Forward3D frame |
| `lynx_viewport_destroy` | teardown |

Flutter: `lynx3d_core_viewport_io.dart`, MethodChannel `lynx/viewport` → `getViewHwnd`.

---

## Сборка

```powershell
cd Lynx/engine
cargo build --release
```

`engine/Cargo.toml` включает `lynx-core` feature `pal_win_d3d12`.

Player Windows:

```powershell
cd Lynx/client
flutter build windows -t lib/main_player.dart --release
```

---

## Регрессия

```powershell
Lynx/scripts/run-q3-regression.ps1
```
