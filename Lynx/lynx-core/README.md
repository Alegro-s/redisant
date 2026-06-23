# Lynx Core

Собственное игровое ядро Lynx. См. `docs/LYNX_CORE_ARCHITECTURE.md`.

## Модули (заготовка v0.0.1)

- `math` — векторы, матрицы
- `mem` — arena allocator
- `platform` — PAL (пока stub)
- `render` / `physics` / `audio` / `script` / `asset` / `scene` — контракты

## Сборка

```bash
cd Lynx/lynx-core
cargo test
```

### M1 (Windows): D3D12 demo

```bash
cargo run --features pal_win_d3d12 --bin lynx-m1-demo -- --frames 2
```

См. `docs/LYNX_CORE_M1.md`, `scripts/run-m1-regression.ps1`.

### M2 (Windows): 2D batch + D3D12

```bash
cargo run --features pal_win_d3d12 --bin lynx-m2-demo -- --frames 2
```

См. `docs/LYNX_CORE_M2.md`, `scripts/run-m2-regression.ps1`. Legacy `engine` линкует `lynx-core` и экспортирует `batch2d_*`, `scene_fill_batch2d`.

### M3 (Windows): forward 3D + `lynx.3d` JSON

```bash
cargo run --features pal_win_d3d12 --bin lynx-m3-demo -- --frames 2
```

См. `docs/LYNX_CORE_M3.md`, `scripts/run-m3-regression.ps1`. Плагин `lynx.3d` в `engine` парсит тот же JSON через `scene3d`.

Legacy `engine/` остаётся рабочим до полной миграции рендера в Player.
