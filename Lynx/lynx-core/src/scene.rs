//! Сцена и сущности (ECS-lite, scene graph).

pub mod runtime;

#[cfg(feature = "serde")]
use serde::{Deserialize, Serialize};

pub use runtime::SceneRuntime;

#[derive(Clone, Debug)]
#[cfg_attr(feature = "serde", derive(Serialize, Deserialize))]
pub struct EntityId(pub u32);

pub struct Scene {
    pub next_id: u32,
}

impl Default for Scene {
    fn default() -> Self {
        Self { next_id: 1 }
    }
}
