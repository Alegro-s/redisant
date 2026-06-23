# Lynx Editor — паритет с Godot (2D студия)

Чеклист волны **9** (цель ≥ 80% для 2D-авторинга). Статус: **9d**.

| # | Godot | Lynx | Статус |
|---|-------|------|--------|
| 1 | Scene tree + layers | Слои, объекты, z-order | ✅ |
| 2 | Inspector properties | `scene_object_inspector.dart` | ✅ |
| 3 | Sprite / UV | Sprite Editor + meta | ✅ |
| 4 | TileMap layers | `tilemaps`, autotile, collision | ✅ |
| 5 | TileMap collision edit | Кисть collision + оверлей **9c** | ✅ |
| 6 | AnimationPlayer clips | `rustAnimationClips` | ✅ |
| 7 | Animation timeline UI | AnimationPlayer v2 дорожки **9a** | ✅ |
| 8 | Animation blend tree | `rustAnimStateMachine` + preview **9a** | ✅ |
| 9 | Key events on frames | `events[]` → signal **9b** | ✅ |
| 10 | Play = Editor (2D) | `platformer-demo`, wave0 | ✅ |
| 11 | Input Map | `input_map` + actions | ✅ |
| 12 | Scene change | `load_scene` / SceneRuntime | ✅ |
| 13 | In-game UI | `layer_ui` | ✅ |
| 14 | Behavior Tree editor | BT dialog wave 5 | ✅ |
| 15 | BT debug in Play | overlay + breakpoint | ✅ волна 10 |
| 16 | UI anchors / themes | anchor + margin + theme | ✅ волна 10 |
| 17 | Debugger breakpoints | — | 🔲 |
| 18 | 3D native viewport | `lynx.3d` + Core M3 | ✅ preview |
| 19 | Export 3 platforms | wave 3 | ✅ |
| 20 | Asset library | Hub wave 7–8 | ✅ |

**Итого:** 18 / 20 = **90%** для 2D-студии (пункт 17 debugger breakpoints — вне scope).

---

## Проверка

```powershell
cd Lynx/client
flutter test test/wave9_editor_test.dart
Lynx/scripts/run-wave9-regression.ps1
```

Проект: `projects/platformer-demo` — герой с `events` на клипе `run`.
