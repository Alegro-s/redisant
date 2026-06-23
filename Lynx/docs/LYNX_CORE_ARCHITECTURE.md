# Lynx Core — архитектура собственного игрового движка

Цель: **универсальный движок целиком на своём коде**, по духу близкий к **id Tech** (id Software) и **Source** (Valve): один стек C/Rust, свои подсистемы, минимум внешних зависимостей в **рантайме игры**.

> **Lynx Cloud API** (`server/`) — инфраструктура (HTTP, JSON, файлы).  
> **Lynx Core** (`lynx-core/`) — игровое ядро: здесь **нет** wgpu, Bullet, Rapier, SDL, Lua (в перспективе).

Текущий crate `engine/` — **Legacy Core v0** (переходный): FFI + Lua (mlua) + 2D. Новые возможности 3D/PBR идут в **Lynx Core v1**, затем Legacy делегирует в Core.

---

## 1. Слои продукта

```
┌─────────────────────────────────────────────────────────┐
│  Lynx Hub / Launcher / Editor (Flutter)                 │
│  — UI, сцены JSON v3, маркетплейс, export               │
└───────────────────────────┬─────────────────────────────┘
                            │ FFI / texture / input
┌───────────────────────────▼─────────────────────────────┐
│  Lynx Core (lynx-core) — СВОЙ код                         │
│  PAL · Render · Physics · Audio · Script · Asset · ECS-lite│
└───────────────────────────┬─────────────────────────────┘
┌───────────────────────────▼─────────────────────────────┐
│  OS: Win32 · Linux · Android · iOS · Web (WASM PAL)      │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Crate `lynx-core` (новое ядро)

Каталог: `Lynx/lynx-core/`

| Модуль | Назначение | Зависимости |
|--------|------------|-------------|
| `lynx_math` | Vec2/3/4, Mat4, quat, AABB, frustum | **только std** |
| `lynx_mem` | Arena, pool, stack allocator для кадра | **только std** |
| `lynx_platform` | Окно, время, файлы, потоки, GPU surface | OS API (winapi / libc / JNI) |
| `lynx_render` | 2D batch + 3D PBR pipeline | **свой** RHI поверх PAL |
| `lynx_physics` | 2D grid + 3D AABB → full solver | **свой** integrator |
| `lynx_audio` | PCM mix, bus, 3D attenuation | **свой** mixer |
| `lynx_script` | VM «LynxScript» (байткод) | **свой** VM |
| `lynx_asset` | Бинарный `.lynxpack`, hot reload | **свой** формат |
| `lynx_scene` | Сцена, entities, components | serde только на границе FFI |

### 2.1 Render (как id / Valve, без Unity-магии)

- **RHI** (Render Hardware Interface): свои enum форматов, буферов, шейдеров (байткод → DXIL/SPIR-V/MSL через **тонкий** транслятор, либо hand-written backends).
- **Фаза 1 (v1):** 2D sprite batch + 3D forward PBR (directional + shadow map 2k).
- **Фаза 2:** skinning (матрицы костей), LOD, occlusion culling (hi-z).
- **Фаза 3:** terrain clipmap, декали, post (bloom, tone map).

Не используем: wgpu, Vulkan-Hpp как «движок» — только прямые вызовы **Vulkan 1.2 / D3D12 / Metal** из `lynx_platform`.

### 2.2 Physics

- **2D:** сохранить grid broadphase из Legacy, перенести в `lynx_physics`.
- **3D:** AABB → swept AABB → optional GJK (свой код, без Rapier).
- Фиксированный шаг 1/60, детерминизм для сетевого replay (задел).

### 2.3 Script

- **LynxScript:** lexer/parser/compiler в Rust → байткод.
- API: `entity`, `input`, `scene`, совместимость с текущими именами Lua (`load_scene`, `action_*`) через **адаптер** на переходный период.
- Legacy: mlua остаётся в `engine/` до паритета API, затем feature flag `legacy_lua`.

### 2.4 Asset

- `.lynxmesh`, `.lynxanim`, `.lynxtex` — бинарные, без GLTF в рантайме (конвертер в Editor).
- Импорт GLTF/FBX — **только в Editor** (Flutter или offline `lynx-import` tool).

---

## 3. Миграция с `engine/` (Legacy)

| Этап | Действие |
|------|----------|
| M0 | Объявить `lynx-core`, пустые модули + тесты math/mem |
| M1 | PAL Windows: окно + D3D12 clear ✅ — [LYNX_CORE_M1.md](LYNX_CORE_M1.md) |
| M2 | 2D batch в Core; Legacy FFI вызывает Core ✅ — [LYNX_CORE_M2.md](LYNX_CORE_M2.md) |
| M3 | 3D forward PBR-lite + shadow 2k; плагин `lynx.3d` → тот же JSON ✅ — [LYNX_CORE_M3.md](LYNX_CORE_M3.md) |
| M4 | LynxScript v1; dual-run с Lua ✅ — [LYNX_CORE_M4.md](LYNX_CORE_M4.md) |
| M5 | LynxScript v2 + SceneRuntime + `legacy_lua` optional ✅ — [LYNX_CORE_M5_M6.md](LYNX_CORE_M5_M6.md) |
| M6 | WASM PAL stub + mobile FFI parity ✅ — [LYNX_CORE_M5_M6.md](LYNX_CORE_M5_M6.md) |

Срок: **12–24 месяца** при выделенной команде; параллельно волны 9–11 редактора.

---

## 4. Экосистема (Hub + Cloud)

Не Asset Store Unity — **свой** каталог:

- Hub: витрина, новости, ссылки на ядра.
- Cloud API: `GET /v1/marketplace/catalog`, `claim`, `download` (волна 8 ✅).
- Пакеты: плагины, шаблоны, `.lynxpack` ассеты, версии **Lynx Core** с semver и checksum.

---

## 5. Что **не** делаем

| Чужое | Почему |
|-------|--------|
| Unity / Godot runtime | Не наш стек, не наш контроль |
| wgpu / Bevy / Rapier в **Core** | Зависимость и чужой roadmap |
| Полный ECS как EnTT | Остаёмся scene-graph + components lite |

Допустимо в **инструментах** (не в кадре игры): Flutter Editor, serde на границе FFI, axum в Cloud API.

---

## 6. Метрики «свой движок»

| Метрика | Цель |
|---------|------|
| Строки стороннего кода в hot path кадра | → 0 к M5 |
| Платформы с одним PAL | Win + Android к M2 |
| 3D PBR demo без Canvas | M3 ✅ `lynx-m3-demo` |
| Маркетплейс → установка в проект | волна 8 ✅ |

---

## 7. Ссылки

- [ENGINE_UNIVERSAL.md](ENGINE_UNIVERSAL.md) — волны продукта  
- [ECOSYSTEM_CLOUD_HUB.md](ECOSYSTEM_CLOUD_HUB.md) — каталог  
- [CLOUD_API_WAVE8.md](CLOUD_API_WAVE8.md) — запуск `lynx-server`  
- `lynx-core/README.md` — карта модулей crate  
- [LYNX_CORE_M1.md](LYNX_CORE_M1.md) — Win32 + D3D12, `lynx-m1-demo`  
- [LYNX_CORE_M2.md](LYNX_CORE_M2.md) — 2D batch, `lynx-m2-demo`, FFI из `engine`  
- [LYNX_CORE_M3.md](LYNX_CORE_M3.md) — forward 3D, `lynx-m3-demo`, `scene3d`  
- [BETA_FREE.md](BETA_FREE.md) — бета без монетизации  
