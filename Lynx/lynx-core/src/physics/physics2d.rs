//! E27 — 2D AABB physics in Lynx Core (unified with 3D module).

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BodyType2d {
    Static,
    Dynamic,
}

#[derive(Clone, Debug)]
pub struct RigidBody2d {
    pub id: u32,
    pub body_type: BodyType2d,
    pub position: [f32; 2],
    pub velocity: [f32; 2],
    pub half_extents: [f32; 2],
}

#[derive(Clone, Debug, Default)]
pub struct Physics2dWorld {
    pub gravity_y: f32,
    pub bodies: Vec<RigidBody2d>,
    pub floor_y: f32,
}

impl Physics2dWorld {
    pub fn new() -> Self {
        Self {
            gravity_y: 980.0,
            bodies: Vec::new(),
            floor_y: 0.0,
        }
    }

    pub fn add_dynamic(&mut self, id: u32, x: f32, y: f32, hw: f32, hh: f32) {
        self.bodies.push(RigidBody2d {
            id,
            body_type: BodyType2d::Dynamic,
            position: [x, y],
            velocity: [0.0, 0.0],
            half_extents: [hw.max(0.01), hh.max(0.01)],
        });
    }

    pub fn step(&mut self, dt: f32) {
        let dt = dt.clamp(0.0, 1.0 / 15.0);
        for body in &mut self.bodies {
            if body.body_type != BodyType2d::Dynamic {
                continue;
            }
            body.velocity[1] += self.gravity_y * dt;
            body.position[0] += body.velocity[0] * dt;
            body.position[1] += body.velocity[1] * dt;
            let bottom = body.position[1] + body.half_extents[1];
            if bottom >= self.floor_y {
                body.position[1] = self.floor_y - body.half_extents[1];
                if body.velocity[1] > 0.0 {
                    body.velocity[1] = 0.0;
                }
            }
        }
    }

    pub fn body_position(&self, index: usize) -> Option<[f32; 2]> {
        self.bodies.get(index).map(|b| b.position)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dynamic_falls_to_floor() {
        let mut w = Physics2dWorld::new();
        w.add_dynamic(1, 0.0, -100.0, 16.0, 16.0);
        for _ in 0..120 {
            w.step(1.0 / 60.0);
        }
        let pos = w.body_position(0).unwrap();
        assert!(pos[1] <= -16.0 + 0.01);
    }
}
