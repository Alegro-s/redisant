# Lynx Core M4 — LynxScript v1 + dual-run Lua

**Версия crate:** `0.4.0-m4`  
**API:** `CORE_API_VERSION = 3`

M4 — минимальная **собственная VM** для entity-скриптов с magic `#lynxscript`. Legacy `engine/` выполняет LynxScript **до** mlua: если код начинается с `#lynxscript`, Lua не вызывается.

---

## Компоненты

| Модуль | Путь |
|--------|------|
| Magic / detect | `lynx-core/src/script/mod.rs` |
| Компилятор subset | `script/compiler.rs` |
| VM | `script/vm.rs` |
| Bridge в engine | `engine/src/lynxscript_bridge.rs` |
| C FFI | `lynx-core/src/ffi.rs` → reexport в `engine` |

### Поддерживаемый синтаксис (v1)

```text
#lynxscript
if action_pressed("jump") then
  y = y - 400 * dt
end
```

- `action_pressed("jump")` — bool → stack (1.0 / 0.0)
- `y = y - N * dt` — изменение глобала `y`
- Глобалы: `x`, `y`, `dt`, `on_ground` (read-only в VM)

---

## Dual-run в `engine`

`run_entity_lua` → `lynxscript_bridge::run_entity_script`:

1. `is_lynxscript(code)` → compile + `run_script` → обновить `entity.transform`
2. Иначе — прежний mlua path

Jump action: `input_map["jump"]` || `key_space` || `gp_a`.

---

## FFI

| Функция | Назначение |
|---------|------------|
| `lynxscript_is(source)` | 1 если `#lynxscript` |
| `lynxscript_run(source, LynxScriptEntityState*)` | 0 = not lynxscript, 1 = ok, 2 = error |

`LynxScriptEntityState`: `x`, `y`, `dt`, `on_ground`, `action_jump` (in/out для x/y).

---

## Сборка и тесты

```powershell
cd Lynx/lynx-core
cargo test script::
cd ../engine
cargo test lynxscript
```

---

## Регрессия

```powershell
Lynx/scripts/run-m4-regression.ps1
```

Включает M3 regression + unit-тесты LynxScript.

---

## Не в M4 (M5+)

- Полный паритет Lua API (`load_scene`, `emit_signal`, …)
- Отключение mlua по умолчанию (M5)
- Байткод на диск / hot reload

См. [LYNX_CORE_ARCHITECTURE.md](LYNX_CORE_ARCHITECTURE.md), [ROADMAP_TECH_FINISH.md](ROADMAP_TECH_FINISH.md).
