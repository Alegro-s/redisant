//! Dual-run LynxScript + Lua (M4–M5).

use crate::{Entity, KeyState, platformer::GamepadState};
use lynx_core::script::{compile, is_lynxscript, run_script, ScriptHost};

pub fn run_entity_script(
    entity: &mut Entity,
    script_code: &str,
    dt: f32,
    ks: &KeyState,
    gp: &GamepadState,
    actions: &std::collections::HashMap<String, bool>,
) -> bool {
    if !is_lynxscript(script_code) {
        return false;
    }
    let prog = match compile(script_code) {
        Ok(p) => p,
        Err(_) => return true,
    };
    let vx = entity
        .physics
        .as_ref()
        .map(|p| p.velocity.x)
        .unwrap_or(0.0);
    let vy = entity
        .physics
        .as_ref()
        .map(|p| p.velocity.y)
        .unwrap_or(0.0);
    let mut host = ScriptHost {
        x: entity.transform.pos.x,
        y: entity.transform.pos.y,
        vx,
        vy,
        dt,
        on_ground: entity.on_ground,
        key_a: ks.a,
        key_d: ks.d,
        key_space: ks.space || gp.face_a,
        actions: actions.clone(),
        velocity_set: false,
        out_vx: vx,
        out_vy: vy,
    };
    if run_script(&prog, &mut host).is_ok() {
        entity.transform.pos.x = host.x;
        entity.transform.pos.y = host.y;
        if host.velocity_set {
            if let Some(phys) = &mut entity.physics {
                phys.velocity.x = host.out_vx;
                phys.velocity.y = host.out_vy;
            }
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Vec2;

    #[test]
    fn lynxscript_runs_on_entity() {
        let mut e = Entity::new(1, "t", Vec2::new(0.0, 50.0), crate::Color::WHITE);
        e.on_ground = true;
        let code = r#"#lynxscript
if action_pressed("jump") then
  y = y - 400 * dt
end
"#;
        let mut actions = std::collections::HashMap::new();
        actions.insert("jump".into(), true);
        let ks = KeyState::default();
        let gp = GamepadState::default();
        assert!(run_entity_script(&mut e, code, 0.016, &ks, &gp, &actions));
        assert!(e.transform.pos.y < 50.0);
    }

    #[test]
    fn platformer_velocity_from_keys() {
        let mut e = Entity::new(1, "player", Vec2::ZERO, crate::Color::WHITE);
        e.physics = Some(crate::PhysicsBody {
            velocity: Vec2::new(0.0, 100.0),
            mass: 1.0,
            is_static: false,
            use_gravity: true,
            bounciness: 0.0,
            shape: crate::ColliderShape::Aabb,
            collision_layer: 1,
            collision_mask: u32::MAX,
            is_trigger: false,
            one_way: false,
        });
        e.on_ground = true;
        let code = r#"#lynxscript
set_velocity(0, vy)
if key_a then
  set_velocity(-260, vy)
end
"#;
        let ks = {
            let mut k = KeyState::default();
            k.a = true;
            k
        };
        let gp = GamepadState::default();
        let actions = std::collections::HashMap::new();
        assert!(run_entity_script(&mut e, code, 0.016, &ks, &gp, &actions));
        assert_eq!(e.physics.as_ref().unwrap().velocity.x, -260.0);
        assert_eq!(e.physics.as_ref().unwrap().velocity.y, 100.0);
    }
}
