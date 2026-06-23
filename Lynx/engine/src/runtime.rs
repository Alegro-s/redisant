//! Волна 2 / M5c: input map, сигналы, смена сцены (Core SceneRuntime).

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use crate::{KeyState, Scene};
use lynx_core::scene::SceneRuntime;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SignalEvent {
    pub name: String,
    pub source_id: usize,
}

pub fn default_scene_runtime() -> Arc<Mutex<SceneRuntime>> {
    Arc::new(Mutex::new(SceneRuntime::new()))
}

pub fn default_signal_queue() -> Arc<Mutex<Vec<SignalEvent>>> {
    Arc::new(Mutex::new(Vec::new()))
}

pub fn resolve_input_actions(ks: &KeyState, map: &HashMap<String, Vec<String>>) -> HashMap<String, bool> {
    let mut out = HashMap::new();
    for (action, keys) in map {
        let pressed = keys.iter().any(|k| key_token_pressed(ks, k));
        out.insert(action.clone(), pressed);
    }
    out
}

fn key_token_pressed(ks: &KeyState, token: &str) -> bool {
    match token.trim().to_uppercase().as_str() {
        "W" => ks.w,
        "A" => ks.a,
        "S" => ks.s,
        "D" => ks.d,
        "SPACE" | "SPACEBAR" => ks.space,
        "LEFT" | "ARROWLEFT" => ks.left,
        "RIGHT" | "ARROWRIGHT" => ks.right,
        "UP" | "ARROWUP" => ks.up,
        "DOWN" | "ARROWDOWN" => ks.down,
        "RETURN" | "ENTER" => ks.enter,
        _ => false,
    }
}

pub struct LuaRuntimeHooks {
    pub scene_runtime: Arc<Mutex<SceneRuntime>>,
    pub signal_queue: Arc<Mutex<Vec<SignalEvent>>>,
}

impl LuaRuntimeHooks {
    pub fn from_scene(scene: &Scene) -> Self {
        Self {
            scene_runtime: scene.scene_runtime.clone(),
            signal_queue: scene.signal_queue.clone(),
        }
    }
}

#[cfg(feature = "legacy_lua")]
mod lua {
    use super::*;
    use mlua::Lua;
    use std::sync::{Arc, Mutex};

    pub fn register_lua_runtime(lua: &Lua, hooks: &LuaRuntimeHooks, actions: &HashMap<String, bool>) {
        let globals = lua.globals();
        for (name, pressed) in actions {
            let key = format!("action_{}", name);
            let _ = globals.set(key.as_str(), *pressed);
        }

        let rt = hooks.scene_runtime.clone();
        let load_scene = lua
            .create_function(move |_, scene_id: String| {
                rt.lock().unwrap().load_scene(scene_id);
                Ok(())
            })
            .unwrap();
        let _ = globals.set("load_scene", load_scene);

        let rt_push = hooks.scene_runtime.clone();
        let push_scene = lua
            .create_function(move |_, scene_id: String| {
                rt_push.lock().unwrap().push_scene(scene_id);
                Ok(())
            })
            .unwrap();
        let _ = globals.set("push_scene", push_scene);

        let rt_pop = hooks.scene_runtime.clone();
        let pop_scene = lua
            .create_function(move |_, ()| {
                rt_pop.lock().unwrap().pop_scene();
                Ok(())
            })
            .unwrap();
        let _ = globals.set("pop_scene", pop_scene);
    }

    pub fn register_lua_emit_signal(lua: &Lua, source_id: usize, signal_queue: &Arc<Mutex<Vec<SignalEvent>>>) {
        let sq = signal_queue.clone();
        let emit_signal = lua
            .create_function(move |_, name: String| {
                sq.lock().unwrap().push(SignalEvent {
                    name,
                    source_id,
                });
                Ok(())
            })
            .unwrap();
        let _ = lua.globals().set("emit_signal", emit_signal);
    }

    pub fn dispatch_scene_signals(scene: &mut Scene, log_q: &Arc<Mutex<Vec<String>>>) {
        let events: Vec<SignalEvent> = scene.signal_queue.lock().unwrap().drain(..).collect();
        if events.is_empty() {
            return;
        }

        let handlers: Vec<(usize, String)> = scene
            .entities
            .iter()
            .filter_map(|e| e.script.as_ref().map(|s| (e.id, s.code.clone())))
            .collect();

        for ev in events {
            for (eid, code) in &handlers {
                if lynx_core::script::is_lynxscript(code) {
                    continue;
                }
                run_lua_on_signal(*eid, code, &ev.name, ev.source_id, log_q);
            }
        }
    }

    fn run_lua_on_signal(
        self_id: usize,
        code: &str,
        signal_name: &str,
        source_id: usize,
        log_q: &Arc<Mutex<Vec<String>>>,
    ) {
        let lua = Lua::new();
        let globals = lua.globals();
        let _ = globals.set("id", self_id as i64);
        let _ = globals.set("signal_name", signal_name);
        let _ = globals.set("source_id", source_id as i64);
        if let Err(e) = lua.load(code).exec() {
            let mut g = log_q.lock().unwrap();
            g.push(format!("signal lua load e{self_id}: {e}"));
            while g.len() > 200 {
                g.remove(0);
            }
            return;
        }
        if let Ok(f) = globals.get::<mlua::Function>("on_signal") {
            if let Err(e) = f.call::<()>(()) {
                let mut g = log_q.lock().unwrap();
                g.push(format!("on_signal e{self_id} {signal_name}: {e}"));
                while g.len() > 200 {
                    g.remove(0);
                }
            }
        }
    }
}

#[cfg(feature = "legacy_lua")]
pub use lua::{dispatch_scene_signals, register_lua_emit_signal, register_lua_runtime};

#[cfg(not(feature = "legacy_lua"))]
pub fn dispatch_scene_signals(_scene: &mut Scene, _log_q: &Arc<Mutex<Vec<String>>>) {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn input_map_resolves_actions() {
        let mut ks = KeyState::default();
        ks.a = true;
        ks.space = true;
        let mut map = HashMap::new();
        map.insert("move_left".into(), vec!["A".into()]);
        map.insert("jump".into(), vec!["Space".into()]);
        let a = resolve_input_actions(&ks, &map);
        assert_eq!(a.get("move_left"), Some(&true));
        assert_eq!(a.get("jump"), Some(&true));
        assert!(!a.contains_key("move_right"));
    }

    #[test]
    fn scene_runtime_load_take() {
        let mut rt = SceneRuntime::new();
        rt.load_scene("main");
        assert_eq!(rt.take_pending_load().as_deref(), Some("main"));
    }
}
