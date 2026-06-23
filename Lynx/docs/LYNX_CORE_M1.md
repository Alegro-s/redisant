# Lynx Core M1 — Win32 PAL + D3D12

**Версия crate:** `0.1.0-m1`  
**Feature:** `pal_win_d3d12`

M1 — первый рабочий кадр собственного ядра: нативное окно Windows и очистка swap chain через D3D12 (без wgpu и сторонних game-рантаймов).

---

## Что входит

| Компонент | Путь |
|-----------|------|
| PAL Win32 + D3D12 | `lynx-core/src/pal/win_d3d12.rs` |
| Демо-бинарник | `lynx-core/src/bin/lynx_m1_demo.rs` → `lynx-m1-demo` |
| Цвет кадра | `lynx-core/src/render/mod.rs` (`Color`) |

Поведение демо:

- Создание окна (`RegisterClassW`, message pump).
- `D3D12CreateDevice`, swap chain, RTV heap, command allocator/list.
- Каждый кадр: `ClearRenderTargetView` + `Present`.
- **Escape** — выход; **WM_CLOSE** — выход.
- **`--frames N`** — для CI: N презентов без интерактива.

---

## Сборка и запуск

```powershell
cd Lynx/lynx-core
cargo build --features pal_win_d3d12 --bin lynx-m1-demo
cargo run --features pal_win_d3d12 --bin lynx-m1-demo
cargo run --features pal_win_d3d12 --bin lynx-m1-demo -- --frames 2 --width 800 --height 450
```

Ожидаемый вывод CI:

```text
Lynx Core M1 OK: backend=D3D12, frames=2
```

---

## Регрессия

```powershell
Lynx/scripts/run-m1-regression.ps1
```

Скрипт: `cargo test` в `lynx-core`, сборка `lynx-m1-demo`, прогон `--frames 2`.

---

## Следующий этап (M2, не в M1)

- 2D sprite batch в Core.
- Legacy `engine/` FFI делегирует рендер в Core.
- Android PAL — отдельный milestone.

См. [LYNX_CORE_ARCHITECTURE.md](LYNX_CORE_ARCHITECTURE.md) §3.
