//! Persistent Lua VM for TIC/cart scripts (`function TIC()` / `function BOOT()`).

#[cfg(feature = "legacy_lua")]
use std::cell::RefCell;
#[cfg(feature = "legacy_lua")]
use std::collections::HashMap;
#[cfg(feature = "legacy_lua")]
use std::hash::{Hash, Hasher};
#[cfg(feature = "legacy_lua")]
use std::sync::{Arc, Mutex};

#[cfg(feature = "legacy_lua")]
use mlua::Lua;

#[cfg(feature = "legacy_lua")]
use crate::input_frame::InputFrame;
#[cfg(feature = "legacy_lua")]
use crate::platformer::GamepadState;
#[cfg(feature = "legacy_lua")]
use crate::runtime;
#[cfg(feature = "legacy_lua")]
use crate::tic_api;
#[cfg(feature = "legacy_lua")]
use crate::{Entity, KeyState, LogicGrid};

#[cfg(feature = "legacy_lua")]
thread_local! {
    static POOLS: RefCell<HashMap<u64, VmState>> = RefCell::new(HashMap::new());
}

#[cfg(feature = "legacy_lua")]
struct VmState {
    lua: Lua,
    code_hash: u64,
    has_tic: bool,
    has_boot: bool,
    booted: bool,
}

#[cfg(feature = "legacy_lua")]
fn hash_code(code: &str) -> u64 {
    let mut h = std::collections::hash_map::DefaultHasher::new();
    code.hash(&mut h);
    h.finish()
}

pub fn wants_persistent(code: &str) -> bool {
    code.contains("function TIC")
        || code.contains("spr(")
        || code.contains("map(")
        || code.contains("pix(")
        || code.contains("btn(")
}

#[cfg(feature = "legacy_lua")]
pub fn run_persistent_frame(
    entity: &mut Entity,
    logic_grids: &mut HashMap<String, LogicGrid>,
    code: &str,
    dt: f32,
    ks: KeyState,
    gp: GamepadState,
    frame: &InputFrame,
    hooks: &runtime::LuaRuntimeHooks,
    actions: &HashMap<String, bool>,
    sound_q: Arc<Mutex<Vec<String>>>,
    log_q: Arc<Mutex<Vec<String>>>,
) {
    let grids_ptr: *mut HashMap<String, LogicGrid> = logic_grids;
    tic_api::bind_runtime(grids_ptr, *frame);

    let key = (entity.id as u64) ^ hash_code(code);
    let code_hash = hash_code(code);

    POOLS.with(|cell| {
        let mut pools = cell.borrow_mut();
        let needs_new = match pools.get(&key) {
            Some(vm) => vm.code_hash != code_hash,
            None => true,
        };
        if needs_new {
            pools.remove(&key);
            let lua = Lua::new();
            let eid = entity.id;
            runtime::register_lua_runtime(&lua, hooks, actions);
            runtime::register_lua_emit_signal(&lua, eid, &hooks.signal_queue);
            tic_api::register_tic_lua_globals(&lua, grids_ptr, *frame, sound_q.clone());

            let lq = log_q.clone();
            let nexus_log = lua
                .create_function(move |_, msg: String| {
                    let mut g = lq.lock().unwrap();
                    g.push(format!("lua e{eid}: {msg}"));
                    if g.len() > 200 {
                        g.remove(0);
                    }
                    Ok(())
                })
                .unwrap();
            let _ = lua.globals().set("nexus_log", nexus_log);

            let mut vm = VmState {
                lua,
                code_hash,
                has_tic: false,
                has_boot: false,
                booted: false,
            };
            if let Err(e) = vm.lua.load(code).exec() {
                push_log(&log_q, &format!("tic load e{}: {e}", entity.id));
                pools.insert(key, vm);
                return;
            }
            vm.has_tic = vm.lua.globals().get::<mlua::Function>("TIC").is_ok();
            vm.has_boot = vm.lua.globals().get::<mlua::Function>("BOOT").is_ok();
            pools.insert(key, vm);
        }

        let vm = pools.get_mut(&key).unwrap();
        let globals = vm.lua.globals();
        let _ = globals.set("dt", dt);
        let _ = globals.set("id", entity.id as i32);
        let _ = globals.set("x", entity.transform.pos.x);
        let _ = globals.set("y", entity.transform.pos.y);
        let _ = globals.set("key_w", ks.w);
        let _ = globals.set("key_a", ks.a);
        let _ = globals.set("key_s", ks.s);
        let _ = globals.set("key_d", ks.d);
        let _ = globals.set("key_space", ks.space);
        let _ = globals.set("key_left", ks.left);
        let _ = globals.set("key_right", ks.right);
        let _ = globals.set("key_up", ks.up);
        let _ = globals.set("key_down", ks.down);
        let _ = globals.set("key_enter", ks.enter);
        let _ = globals.set("gp_a", gp.face_a);
        let _ = globals.set("gp_b", gp.face_b);

        if vm.has_boot && !vm.booted {
            if let Ok(f) = globals.get::<mlua::Function>("BOOT") {
                if let Err(e) = f.call::<()>(()) {
                    push_log(&log_q, &format!("BOOT e{}: {e}", entity.id));
                }
            }
            vm.booted = true;
        }

        if vm.has_tic {
            if let Ok(f) = globals.get::<mlua::Function>("TIC") {
                if let Err(e) = f.call::<()>(()) {
                    push_log(&log_q, &format!("TIC e{}: {e}", entity.id));
                }
            }
        } else if let Err(e) = vm.lua.load(code).exec() {
            push_log(&log_q, &format!("lua e{}: {e}", entity.id));
        }

        if let Ok(x) = globals.get::<f32>("new_x") {
            entity.transform.pos.x = x;
        }
        if let Ok(y) = globals.get::<f32>("new_y") {
            entity.transform.pos.y = y;
        }
        if let Some(phys) = &mut entity.physics {
            if let Ok(vx) = globals.get::<f32>("new_vx") {
                phys.velocity.x = vx;
            }
            if let Ok(vy) = globals.get::<f32>("new_vy") {
                phys.velocity.y = vy;
            }
        }
    });
}

#[cfg(feature = "legacy_lua")]
fn push_log(log_q: &Arc<Mutex<Vec<String>>>, msg: &str) {
    let mut g = log_q.lock().unwrap();
    g.push(msg.to_string());
    if g.len() > 200 {
        g.remove(0);
    }
}

#[cfg(not(feature = "legacy_lua"))]
pub fn run_persistent_frame(
    _entity: &mut crate::Entity,
    _logic_grids: &mut std::collections::HashMap<String, crate::LogicGrid>,
    _code: &str,
    _dt: f32,
    _ks: crate::KeyState,
    _gp: crate::platformer::GamepadState,
    _frame: &crate::input_frame::InputFrame,
    _hooks: &crate::runtime::LuaRuntimeHooks,
    _actions: &std::collections::HashMap<String, bool>,
    _sound_q: std::sync::Arc<std::sync::Mutex<Vec<String>>>,
    _log_q: std::sync::Arc<std::sync::Mutex<Vec<String>>>,
) {
}
