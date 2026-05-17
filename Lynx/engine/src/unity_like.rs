
use serde::{Deserialize, Serialize};

use crate::Vec2;
use crate::io_vec2;

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct EntityAnimator {
    pub clip_id: String,
    pub time: f32,
    pub speed: f32,
    #[serde(default = "default_loop")]
    pub looping: bool,
}

fn default_loop() -> bool {
    true
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AudioSource2D {
    pub clip_path: String,
    #[serde(default = "default_vol")]
    pub volume: f32,
    #[serde(default)]
    pub loop_playback: bool,
}

fn default_vol() -> f32 {
    1.0
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Camera2D {
    pub name: String,
    #[serde(default)]
    pub active: bool,
    #[serde(default)]
    pub target_entity_id: Option<usize>,
    #[serde(with = "io_vec2")]
    pub offset: Vec2,
    pub smoothing: f32,
    pub zoom: f32,
    #[serde(default)]
    pub dead_zone_half_w: f32,
    #[serde(default)]
    pub dead_zone_half_h: f32,
}

impl Default for Camera2D {
    fn default() -> Self {
        Self {
            name: "Main".into(),
            active: true,
            target_entity_id: None,
            offset: Vec2::ZERO,
            smoothing: 8.0,
            zoom: 1.0,
            dead_zone_half_w: 0.0,
            dead_zone_half_h: 0.0,
        }
    }
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct AudioMixerState {
    #[serde(default = "default_master")]
    pub master_volume: f32,
    #[serde(default)]
    pub bus_volumes: std::collections::HashMap<String, f32>,
}

fn default_master() -> f32 {
    1.0
}
