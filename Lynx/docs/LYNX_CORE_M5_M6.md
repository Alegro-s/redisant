# Lynx Core M5–M6 — LynxScript v2 + SceneRuntime + WASM PAL

**Версия crate:** `0.6.0-m6`  
**API:** `CORE_API_VERSION = 4`

---

## M5a — LynxScript расширение

| Возможность | Синтаксис |
|-------------|-----------|
| Клавиши | `if key_a then` / `key_d` / `key_space` |
| Input map | `if action_pressed("jump") then` |
| Скорость | `set_velocity(vx, vy)` — `vx`/`vy` или числа |
| Земля | `if on_ground then` |
| Сигналы | `function on_signal() … end` — игнорируется (stub) |

Эталон: `projects/platformer-demo/assets/scripts/player.lynxscript` (паритет `player.lua`).

Dual-run в `engine`: `#lynxscript` → Core VM, иначе Lua (если `legacy_lua`).

---

## M5b — Feature `legacy_lua`

`engine/Cargo.toml`:

```toml
[features]
default = ["legacy_lua"]
legacy_lua = ["dep:mlua"]
```

Сборка Player без Lua:

```powershell
cd Lynx/engine
cargo build --no-default-features
```

Hot path: только LynxScript + Rust physics.

---

## M5c — SceneRuntime в Core

| Модуль | `lynx-core/src/scene/runtime.rs` |
| FFI | `scene_runtime_create/load/push/pop/take_pending` |
| Engine | `Scene.scene_runtime`, `scene_load`, `scene_take_pending_load` |

---

## M6a — WASM PAL

| Модуль | `lynx-core/src/pal/wasm.rs` |
| API | `init_webgpu_stub(w, h)` → `WasmSurface` |

Сборка:

```powershell
cd Lynx/lynx-core
rustup target add wasm32-unknown-unknown
cargo build --target wasm32-unknown-unknown
```

---

## M6b — Web Player

Play на Web: по-прежнему **WebSceneEngine** (Dart); WASM Core — задел под texture из PAL. Export: `scripts/export-player.ps1 -Preset web`.

---

## M6c — Mobile PAL

Android/iOS: `engine` FFI `scene_fill_batch2d` / `lynx-core` batch — см. `docs/PLATFORM_QA.md` (NDK / xcframework).

---

## Регрессия

```powershell
Lynx/scripts/run-m5-m6-regression.ps1
```
