//! Wave 15: per-tick input edges (stable tick contract).

use std::collections::HashMap;

use crate::platformer::GamepadState;
use crate::KeyState;

#[derive(Clone, Copy, Debug, Default)]
pub struct InputFrame {
    pub keys: KeyState,
    pub keys_prev: KeyState,
    pub gp: GamepadState,
    pub gp_prev: GamepadState,
}

impl InputFrame {
    pub fn key_held(&self, token: &str) -> bool {
        match token.trim().to_uppercase().as_str() {
            "W" => self.keys.w,
            "A" => self.keys.a,
            "S" => self.keys.s,
            "D" => self.keys.d,
            "SPACE" | "SPACEBAR" => self.keys.space,
            "LEFT" | "ARROWLEFT" => self.keys.left,
            "RIGHT" | "ARROWRIGHT" => self.keys.right,
            "UP" | "ARROWUP" => self.keys.up,
            "DOWN" | "ARROWDOWN" => self.keys.down,
            "RETURN" | "ENTER" => self.keys.enter,
            _ => false,
        }
    }

    pub fn key_held_prev(&self, token: &str) -> bool {
        match token.trim().to_uppercase().as_str() {
            "W" => self.keys_prev.w,
            "A" => self.keys_prev.a,
            "S" => self.keys_prev.s,
            "D" => self.keys_prev.d,
            "SPACE" | "SPACEBAR" => self.keys_prev.space,
            "LEFT" | "ARROWLEFT" => self.keys_prev.left,
            "RIGHT" | "ARROWRIGHT" => self.keys_prev.right,
            "UP" | "ARROWUP" => self.keys_prev.up,
            "DOWN" | "ARROWDOWN" => self.keys_prev.down,
            "RETURN" | "ENTER" => self.keys_prev.enter,
            _ => false,
        }
    }

    pub fn key_pressed(&self, token: &str) -> bool {
        self.key_held(token) && !self.key_held_prev(token)
    }

    pub fn btn_pressed(&self, name: &str) -> bool {
        match name.trim().to_lowercase().as_str() {
            "a" | "gp_a" | "jump" | "confirm" => self.gp.face_a && !self.gp_prev.face_a,
            "b" | "gp_b" | "cancel" => self.gp.face_b && !self.gp_prev.face_b,
            "left" | "dleft" | "gp_dleft" => self.gp.dpad_left && !self.gp_prev.dpad_left,
            "right" | "dright" | "gp_dright" => self.gp.dpad_right && !self.gp_prev.dpad_right,
            "up" | "dup" | "gp_dup" => self.gp.dpad_up && !self.gp_prev.dpad_up,
            "down" | "ddown" | "gp_ddown" => self.gp.dpad_down && !self.gp_prev.dpad_down,
            other => self.key_pressed(other),
        }
    }

    pub fn action_pressed(
        actions: &HashMap<String, bool>,
        actions_prev: &HashMap<String, bool>,
        name: &str,
    ) -> bool {
        let cur = actions.get(name).copied().unwrap_or(false);
        let prev = actions_prev.get(name).copied().unwrap_or(false);
        cur && !prev
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn btn_pressed_edge() {
        let mut gp = GamepadState::default();
        gp.face_a = true;
        let frame = InputFrame {
            gp,
            ..Default::default()
        };
        assert!(frame.btn_pressed("a"));
        let frame2 = InputFrame {
            gp,
            gp_prev: gp,
            ..Default::default()
        };
        assert!(!frame2.btn_pressed("a"));
    }
}
