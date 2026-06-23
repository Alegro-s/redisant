//! LynxScript — собственная VM (M4–M5), dual-run с Lua в Legacy `engine/`.

mod compiler;
mod vm;

pub use compiler::{compile, CompileError, Program};
pub use vm::{run_script, ScriptHost, VmError};

pub const MAGIC_PREFIX: &str = "#lynxscript";

pub fn is_lynxscript(source: &str) -> bool {
    source.trim_start().starts_with(MAGIC_PREFIX)
}

/// Заглушка `on_signal` для LynxScript (M5a): блок `function on_signal() … end` игнорируется компилятором.
pub fn has_on_signal_stub(source: &str) -> bool {
    source.contains("function on_signal")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compile_and_run_jump() {
        let src = r#"#lynxscript
if action_pressed("jump") then
  y = y - 400 * dt
end
"#;
        assert!(is_lynxscript(src));
        let prog = compile(src).expect("compile");
        let mut host = ScriptHost {
            x: 0.0,
            y: 100.0,
            vx: 0.0,
            vy: 0.0,
            dt: 0.016,
            on_ground: true,
            key_a: false,
            key_d: false,
            key_space: false,
            actions: [("jump".into(), true)].into_iter().collect(),
            velocity_set: false,
            out_vx: 0.0,
            out_vy: 0.0,
        };
        run_script(&prog, &mut host).expect("run");
        assert!(host.y < 100.0);
    }

    #[test]
    fn platformer_set_velocity() {
        let src = r#"#lynxscript
set_velocity(0, vy)
if key_a then
  set_velocity(-260, vy)
end
if key_d then
  set_velocity(260, vy)
end
if action_pressed("jump") then
  if on_ground then
    set_velocity(vx, -520)
  end
end
"#;
        let prog = compile(src).expect("compile");
        let mut host = ScriptHost {
            x: 0.0,
            y: 0.0,
            vx: 10.0,
            vy: 5.0,
            dt: 0.016,
            on_ground: true,
            key_a: true,
            key_d: false,
            key_space: false,
            actions: [("jump".into(), false)].into_iter().collect(),
            velocity_set: false,
            out_vx: 0.0,
            out_vy: 0.0,
        };
        run_script(&prog, &mut host).expect("run");
        assert!(host.velocity_set);
        assert_eq!(host.out_vx, -260.0);
        assert_eq!(host.out_vy, 5.0);
    }
}
