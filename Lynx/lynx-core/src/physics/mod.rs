//! Физика Lynx Core.

pub mod physics2d;
pub mod physics3d;

pub use physics2d::{BodyType2d, Physics2dWorld, RigidBody2d};
pub use physics3d::{BodyType3d, Physics3dWorld, RigidBody3d};

pub struct PhysicsWorld {
    pub gravity_y: f32,
}

impl Default for PhysicsWorld {
    fn default() -> Self {
        Self { gravity_y: -9.81 }
    }
}

impl PhysicsWorld {
    pub fn step(&mut self, _dt: f32) {}
}
