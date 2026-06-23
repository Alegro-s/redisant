# Lynx — универсальный игровой движок (целевая архитектура)

Цель: **один продукт** — 2D/3D, редактор уровня Godot, экспорт на Win/Android/iOS/Web, экосистема через **Lynx Hub** (лаунчер) и **Lynx Cloud** (каталог, проекты, сборки).

Стек не меняется: **Rust** (симуляция, физика, скрипты, будущий 3D-рендер) + **Flutter** (редактор, UI, экспорт, витрина).

---

## Что уже есть (волны 0–6)

| Область | Статус |
|---------|--------|
| 2D Play = Editor | ✅ |
| Плагины, runtime (сцены, input map, сигналы) | ✅ |
| Export + Player | ✅ |
| Паритет Win (Android/iOS/Web — базовый) | ✅ частично |
| Редактор Pro (Animation, BT, UI, шаблоны) | ✅ v1 |
| 3D плагин | ✅ preview + GLB mesh (без PBR/скелета) |

---

## Целевые блоки (паритет с Godot)

### A. Экосистема (Hub + Cloud) — волны 7–8

| Возможность | Godot | Lynx (план) |
|-------------|-------|-------------|
| Asset Library | AssetLib | `marketplace-catalog.json` + Launcher «Lynx Cloud» |
| Плагины из каталога | addons | `kind: plugin` → `projects/.../plugins/` |
| Шаблоны проектов | templates | `kind: template` → `lynx_project_templates` |
| Версии ядра | — | `engineCores` в Hub + `minNexusEngineVersion` + `minLynxCoreVersion` |
| Облачный проект | — | уже есть `loadCloudProject` |

**Критерий волны 7:** из Launcher установить плагин/шаблон/пакет ассетов в открытый локальный проект одной кнопкой.

**Критерий волны 8:** Hub-страница «Маркетплейс» + тот же JSON; Cloud API для покупки/лицензий (заглушка → реальный billing).

### B. Инструменты редактора — волны 9–10

| Инструмент | Godot | Lynx (план) |
|------------|-------|-------------|
| AnimationPlayer | ✅ | дорожки, blend, события на ключах |
| Behavior Tree | плагины | визуальный + отладка в Play |
| UI | Control nodes | `layer_ui` + layout anchors, темы |
| TileMap | ✅ | автотайл, слои, collision baked |
| Debugger | ✅ | Lua BT breakpoints, инспектор сущностей в Play |

**Критерий:** side-by-side чеклист «Godot Editor Pro» в `docs/EDITOR_GODOT_PARITY.md` ≥ 80% для 2D-студии.

### C. Паритет платформ — волна 11

| Платформа | Цель |
|-----------|------|
| Windows | эталон, 60 FPS |
| Android / iOS | полный Rust FFI, touch, gamepad |
| Web | WASM ядро **или** полный `WebSceneEngine` с Lua/BT/3D fallback |

**Критерий:** один demo проходит `PLATFORM_QA.md` на всех четырёх без «только Windows».

### D. Полноценный 3D — волны 12–14 (отдельный рендер-модуль)

3D **выносится** из Canvas-preview в нативный проход:

```
engine/crates/lynx_render/   # wgpu: PBR, shadows, GLTF, skinning
engine/crates/lynx_physics3d/ # Rapier3D (или bullet через FFI)
client → FFI lynx_render + Flutter texture / PlatformView
```

| Возможность | Этап |
|-------------|------|
| PBR материалы (metallic-roughness) | 12a |
| Текстуры, normal map | 12b |
| Directional + shadow map | 12c |
| Skeletal animation (GLTF skins) | 13a |
| Terrain heightmap | 13b |
| 3D physics (colliders, rigid body) | 14a |
| Occlusion / LOD | 14b |

Плагин `lynx.3d` остаётся **контрактом сцены**; рендер — `lynx_render` + capability `render.3d.native`.

**Критерий:** demo «комната + PBR объект + персонаж с walk» на Windows; Web — degraded (low poly, no shadows).

---

## Зависимости волн

```
0–6 (готово)
    │
    ├──► 7 Marketplace v1 (Launcher install)
    ├──► 8 Hub + Cloud API v1
    │
    ├──► 9 Editor tools v2 (animation timelines)
    ├──► 10 Editor tools v3 (BT debug, UI layout)
    │
    ├──► 11 Platform parity (WASM / mobile QA)
    │
    └──► 12–14 Lynx Render (PBR 3D) + Physics3D
```

Оценка календаря при 2-недельных спринтах: **7–8** ≈ 1–2 мес., **9–11** ≈ 3–4 мес., **12–14** ≈ 6–9 мес. (команда 2–4 разработчика). Это **реалистичный** путь к «универсальному» движку, не один релиз.

---

## Принципы

1. **Hub = вход**, **Cloud = каталог и хостинг**, **Editor = создание**, **Rust = истина симуляции**.
2. Не дублировать Unity Asset Store — свой каталог JSON/API, совместимый с Hub.
3. 3D preview на Canvas — только до волны 12; затем native render.
4. Каждая волна: demo + `run-waveN-regression.ps1`.

См. также: [ECOSYSTEM_CLOUD_HUB.md](ECOSYSTEM_CLOUD_HUB.md), [LYNX_3D_ENGINE.md](LYNX_3D_ENGINE.md), [ROADMAP_WAVES.md](ROADMAP_WAVES.md).
