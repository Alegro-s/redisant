# Lynx — performance budget (Q4)

Ориентиры для **60 FPS** на целевом железе. Не жёсткие лимиты CI; используйте при профилировании Play и Core.

## 2D Player (Windows, 1080p)

| Подсистема | Бюджет кадра (~16.7 ms) | Примечание |
|------------|-------------------------|------------|
| Rust `scene_update` | ≤ 4 ms | физика grid + скрипты; без mlua — LynxScript |
| Flutter layout + paint | ≤ 8 ms | тайлмапы, спрайты, UI overlay |
| Аудио / IO | ≤ 2 ms | очередь one-shot |
| Запас | ≥ 2 ms | vsync, GC |

## Lynx Core M3 forward 3D (`lynx-m3-demo`)

| Метрика | Цель |
|---------|------|
| Draw calls / кадр | ≤ 32 (комната + объекты) |
| Shadow map | 2048² R32F (фикс.) |
| Mesh | unit cube IA (GLB — отдельный VB в roadmap) |

## Web (`WebSceneEngine`)

| Метрика | Цель |
|---------|------|
| Entities | ≤ 64 активных со скриптами |
| `update(dt)` | ≤ 6 ms на mid-tier ноутбук |

## Регрессия

```powershell
Lynx/scripts/run-all-regression.ps1 -Tier quick
```
