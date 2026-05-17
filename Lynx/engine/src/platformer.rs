
use serde::{Deserialize, Serialize};

use crate::{entity_aabb, is_dynamic_body, Entity, Scene};

pub const TILE_EMPTY: u8 = 0;
pub const TILE_SOLID: u8 = 1;
pub const TILE_ONE_WAY: u8 = 2;
pub const TILE_SLOPE_45_R: u8 = 3;
pub const TILE_SLOPE_45_L: u8 = 4;

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct TileChunk {
    pub cx: i32,
    pub cy: i32,
    pub tw: u32,
    pub th: u32,
    #[serde(default)]
    pub tile_ids: Vec<u32>,
    #[serde(default)]
    pub collision: Vec<u8>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TilemapLayer {
    pub id: String,
    pub tile_w: f32,
    pub tile_h: f32,
    #[serde(default)]
    pub z_order: i32,
    #[serde(default = "default_true")]
    pub visible: bool,
    #[serde(default)]
    pub tileset_id: Option<String>,
    #[serde(default)]
    pub autotile: bool,
    #[serde(default)]
    pub chunks: Vec<TileChunk>,
}

fn default_true() -> bool {
    true
}

impl Default for TilemapLayer {
    fn default() -> Self {
        Self {
            id: "main".into(),
            tile_w: 32.0,
            tile_h: 32.0,
            z_order: 0,
            visible: true,
            tileset_id: None,
            autotile: false,
            chunks: Vec::new(),
        }
    }
}

impl TileChunk {
    pub fn idx(&self, lx: u32, ly: u32) -> Option<usize> {
        if lx >= self.tw || ly >= self.th {
            return None;
        }
        Some((ly * self.tw + lx) as usize)
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RoomZone {
    pub id: String,
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
    #[serde(default)]
    pub camera_min_x: f32,
    #[serde(default)]
    pub camera_min_y: f32,
    #[serde(default)]
    pub camera_max_x: f32,
    #[serde(default)]
    pub camera_max_y: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PlatformerMotor {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default = "def_run")]
    pub run_speed: f32,
    #[serde(default = "def_jump")]
    pub jump_velocity: f32,
    #[serde(default = "def_one")]
    pub gravity_scale: f32,
    #[serde(default = "def_coyote")]
    pub coyote_time: f32,
    #[serde(default = "def_buffer")]
    pub jump_buffer_time: f32,
    #[serde(default = "def_air")]
    pub air_control: f32,
    #[serde(default)]
    pub use_gamepad: bool,
    #[serde(skip, default)]
    coyote_timer: f32,
    #[serde(skip, default)]
    jump_buffer_timer: f32,
}

fn def_run() -> f32 {
    260.0
}
fn def_jump() -> f32 {
    520.0
}
fn def_one() -> f32 {
    1.0
}
fn def_coyote() -> f32 {
    0.12
}
fn def_buffer() -> f32 {
    0.1
}
fn def_air() -> f32 {
    0.65
}

impl Default for PlatformerMotor {
    fn default() -> Self {
        Self {
            enabled: false,
            run_speed: def_run(),
            jump_velocity: def_jump(),
            gravity_scale: def_one(),
            coyote_time: def_coyote(),
            jump_buffer_time: def_buffer(),
            air_control: def_air(),
            use_gamepad: false,
            coyote_timer: 0.0,
            jump_buffer_timer: 0.0,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PatrolAi {
    #[serde(default = "def_patrol_speed")]
    pub speed: f32,
    pub min_x: f32,
    pub max_x: f32,
    #[serde(default = "def_dir")]
    dir: f32,
}

fn def_patrol_speed() -> f32 {
    80.0
}
fn def_dir() -> f32 {
    1.0
}

impl Default for PatrolAi {
    fn default() -> Self {
        Self {
            speed: def_patrol_speed(),
            min_x: 0.0,
            max_x: 200.0,
            dir: 1.0,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "snake_case")]
pub enum AnimConditionKind {
    OnGround,
    InAir,
    SpeedXAbove,
    SpeedXBelow,
    Always,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AnimRule {
    pub clip_id: String,
    pub conditions: Vec<AnimConditionKind>,
    #[serde(default)]
    pub speed_threshold: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AnimStateMachine {
    #[serde(default)]
    pub enabled: bool,
    #[serde(default)]
    pub rules: Vec<AnimRule>,
    #[serde(default = "def_idle")]
    pub fallback_clip: String,
}

fn def_idle() -> String {
    "idle".into()
}

impl Default for AnimStateMachine {
    fn default() -> Self {
        Self {
            enabled: false,
            rules: Vec::new(),
            fallback_clip: def_idle(),
        }
    }
}

impl AnimStateMachine {
    pub fn resolve_clip(&self, on_ground: bool, speed_x: f32) -> String {
        if !self.enabled {
            return String::new();
        }
        'outer: for rule in &self.rules {
            for c in &rule.conditions {
                let ok = match c {
                    AnimConditionKind::OnGround => on_ground,
                    AnimConditionKind::InAir => !on_ground,
                    AnimConditionKind::SpeedXAbove => speed_x.abs() > rule.speed_threshold,
                    AnimConditionKind::SpeedXBelow => speed_x.abs() <= rule.speed_threshold,
                    AnimConditionKind::Always => true,
                };
                if !ok {
                    continue 'outer;
                }
            }
            return rule.clip_id.clone();
        }
        self.fallback_clip.clone()
    }
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
pub struct GamepadState {
    pub stick_lx: f32,
    pub stick_ly: f32,
    pub face_a: bool,
    pub face_b: bool,
    pub dpad_left: bool,
    pub dpad_right: bool,
}

#[derive(Clone, Copy, Debug, Default)]
pub struct PlatformerInputLatch {
    pub prev_kb_space: bool,
    pub prev_gp_a: bool,
}

pub fn step_patrol_ai(scene: &mut Scene, _dt: f32) {
    for e in &mut scene.entities {
        if e.behavior_tree.is_some() {
            continue;
        }
        let Some(ai) = e.patrol_ai.as_mut() else {
            continue;
        };
        let Some(phys) = e.physics.as_mut() else {
            continue;
        };
        if phys.is_static {
            continue;
        }
        let mut dir = ai.dir;
        let x = e.transform.pos.x;
        if x < ai.min_x {
            dir = 1.0;
        } else if x > ai.max_x {
            dir = -1.0;
        }
        phys.velocity.x = dir * ai.speed;
        ai.dir = dir;
    }
}

pub fn step_platformer_motors(scene: &mut Scene, dt: f32) {
    let ks = *scene.key_state.lock().unwrap();
    let gp = *scene.gamepad.lock().unwrap();

    let space_edge = {
        let mut m = scene.platformer_latch.lock().unwrap();
        let k_edge = ks.space && !m.prev_kb_space;
        m.prev_kb_space = ks.space;
        let g_edge = gp.face_a && !m.prev_gp_a;
        m.prev_gp_a = gp.face_a;
        k_edge || g_edge
    };

    for e in &mut scene.entities {
        let Some(mut motor) = e.platformer_motor.take() else {
            continue;
        };
        if !motor.enabled {
            e.platformer_motor = Some(motor);
            continue;
        }
        let Some(phys) = e.physics.as_mut() else {
            e.platformer_motor = Some(motor);
            continue;
        };
        if phys.is_static {
            e.platformer_motor = Some(motor);
            continue;
        }

        let mut hx = 0.0f32;
        if ks.d || gp.dpad_right {
            hx += 1.0;
        }
        if ks.a || gp.dpad_left {
            hx -= 1.0;
        }
        if motor.use_gamepad {
            hx += gp.stick_lx;
        }
        hx = hx.clamp(-1.0, 1.0);

        let ctrl = if e.on_ground { 1.0 } else { motor.air_control };
        let target_vx = hx * motor.run_speed * ctrl;
        phys.velocity.x = target_vx;

        if e.on_ground {
            motor.coyote_timer = motor.coyote_time;
        } else {
            motor.coyote_timer = (motor.coyote_timer - dt).max(0.0);
        }

        if space_edge {
            motor.jump_buffer_timer = motor.jump_buffer_time;
        } else {
            motor.jump_buffer_timer = (motor.jump_buffer_timer - dt).max(0.0);
        }

        let can_jump = e.on_ground || motor.coyote_timer > 0.0;
        if can_jump && motor.jump_buffer_timer > 0.0 {
            phys.velocity.y = -motor.jump_velocity * motor.gravity_scale.max(0.1);
            motor.jump_buffer_timer = 0.0;
            motor.coyote_timer = 0.0;
        }

        e.platformer_motor = Some(motor);
    }
}

pub fn step_anim_state_machines(scene: &mut Scene, _dt: f32) {
    for e in &mut scene.entities {
        let Some(sm) = e.anim_state_machine.as_ref() else {
            continue;
        };
        if !sm.enabled {
            continue;
        }
        let vx = e.physics.as_ref().map(|p| p.velocity.x).unwrap_or(0.0);
        let clip = sm.resolve_clip(e.on_ground, vx);
        if clip.is_empty() {
            continue;
        }
        let changed = e
            .animator
            .as_ref()
            .map(|a| a.clip_id != clip)
            .unwrap_or(true);
        if changed {
            if let Some(anim) = e.animation_clips.get(&clip) {
                e.sprite.animation = Some(anim.clone());
            }
            if let Some(a) = e.animator.as_mut() {
                a.clip_id = clip.clone();
                a.time = 0.0;
            } else {
                e.animator = Some(crate::EntityAnimator {
                    clip_id: clip,
                    time: 0.0,
                    speed: 1.0,
                    looping: true,
                });
            }
        }
    }
}

fn resolve_solid_aabb(a: &crate::PhysRect, b: &crate::PhysRect) -> Option<(f32, f32, bool)> {
    if a.x >= b.x + b.w || a.x + a.w <= b.x || a.y >= b.y + b.h || a.y + a.h <= b.y {
        return None;
    }
    let dx = (a.x + a.w / 2.0 - (b.x + b.w / 2.0)).abs();
    let dy = (a.y + a.h / 2.0 - (b.y + b.h / 2.0)).abs();
    let ox = ((a.w + b.w) / 2.0 - dx).max(0.0);
    let oy = ((a.h + b.h) / 2.0 - dy).max(0.0);
    if ox < oy {
        let dir = if a.x + a.w / 2.0 < b.x + b.w / 2.0 {
            -ox
        } else {
            ox
        };
        Some((dir, 0.0, false))
    } else {
        let dir = if a.y + a.h / 2.0 < b.y + b.h / 2.0 {
            -oy
        } else {
            oy
        };
        Some((0.0, dir, true))
    }
}

fn resolve_slope_r(a: &crate::PhysRect, tile: &crate::PhysRect) -> Option<(f32, f32, bool)> {
    let cx = (a.x + a.w / 2.0).clamp(tile.x, tile.x + tile.w);
    let t = ((cx - tile.x) / tile.w).clamp(0.0, 1.0);
    let surface_y = tile.y + tile.h * (1.0 - t);
    let bottom = a.y + a.h;
    if cx < tile.x || cx > tile.x + tile.w {
        return None;
    }
    if bottom > surface_y && a.y < surface_y + 8.0 {
        let pen = bottom - surface_y;
        if pen > 0.0 && pen < tile.h {
            return Some((0.0, -pen, true));
        }
    }
    None
}

fn resolve_slope_l(a: &crate::PhysRect, tile: &crate::PhysRect) -> Option<(f32, f32, bool)> {
    let cx = (a.x + a.w / 2.0).clamp(tile.x, tile.x + tile.w);
    let t = ((cx - tile.x) / tile.w).clamp(0.0, 1.0);
    let surface_y = tile.y + tile.h * t;
    let bottom = a.y + a.h;
    if bottom > surface_y && a.y < surface_y + 8.0 {
        let pen = bottom - surface_y;
        if pen > 0.0 && pen < tile.h {
            return Some((0.0, -pen, true));
        }
    }
    None
}

fn aabb_tile_overlap(
    a: &crate::PhysRect,
    tile: &crate::PhysRect,
    kind: u8,
    e: &Entity,
) -> Option<(f32, f32, bool)> {
    let phys = e.physics.as_ref()?;
    let bottom = a.y + a.h;
    let tile_top = tile.y;
    let vy = phys.velocity.y;

    match kind {
        TILE_SOLID => resolve_solid_aabb(a, tile),
        TILE_ONE_WAY => {
            if vy <= 0.0 && bottom > tile_top + 4.0 {
                return None;
            }
            if a.x + a.w <= tile.x || a.x >= tile.x + tile.w {
                return None;
            }
            if bottom < tile_top || bottom > tile.y + tile.h + a.h {
                return None;
            }
            let pen = bottom - tile_top;
            if pen > 0.0 && pen < (a.h + tile.h).min(64.0) {
                Some((0.0, -pen, true))
            } else {
                None
            }
        }
        TILE_SLOPE_45_R => resolve_slope_r(a, tile),
        TILE_SLOPE_45_L => resolve_slope_l(a, tile),
        _ => None,
    }
}

fn resolve_entity_against_tiles(e: &mut Entity, layers: &[TilemapLayer]) {
    if !is_dynamic_body(e) {
        return;
    }
    if e.physics.as_ref().map(|p| p.is_trigger).unwrap_or(false) {
        return;
    }
    let mut r = entity_aabb(e);
    let mut layers_sorted: Vec<&TilemapLayer> = layers.iter().collect();
    layers_sorted.sort_by_key(|l| l.z_order);

    for layer in layers_sorted {
        if !layer.visible {
            continue;
        }
        let tw = layer.tile_w.max(1.0);
        let th = layer.tile_h.max(1.0);
        for ch in &layer.chunks {
            let base_x = ch.cx as f32 * ch.tw as f32 * tw;
            let base_y = ch.cy as f32 * ch.th as f32 * th;
            let chunk_wpx = ch.tw as f32 * tw;
            let chunk_hpx = ch.th as f32 * th;
            if r.x >= base_x + chunk_wpx || r.x + r.w <= base_x || r.y >= base_y + chunk_hpx || r.y + r.h <= base_y
            {
                continue;
            }
            let lx0 = (((r.x - base_x) / tw).floor() as i32).clamp(0, ch.tw as i32 - 1) as u32;
            let lx1 = (((r.x + r.w - base_x) / tw).floor() as i32).clamp(0, ch.tw as i32 - 1) as u32;
            let ly0 = (((r.y - base_y) / th).floor() as i32).clamp(0, ch.th as i32 - 1) as u32;
            let ly1 = (((r.y + r.h - base_y) / th).floor() as i32).clamp(0, ch.th as i32 - 1) as u32;
            for ly in ly0..=ly1 {
                for lx in lx0..=lx1 {
                    let Some(i) = ch.idx(lx, ly) else {
                        continue;
                    };
                    if i >= ch.collision.len() {
                        continue;
                    }
                    let kind = ch.collision[i];
                    if kind == TILE_EMPTY {
                        continue;
                    }
                    let wx = base_x + lx as f32 * tw;
                    let wy = base_y + ly as f32 * th;
                    let tile_rect = crate::PhysRect {
                        x: wx,
                        y: wy,
                        w: tw,
                        h: th,
                    };
                    let Some((oxv, oyv, kill_vy)) = aabb_tile_overlap(&r, &tile_rect, kind, e) else {
                        continue;
                    };
                    if oxv.abs() > oyv.abs() {
                        e.transform.pos.x += oxv;
                        r = entity_aabb(e);
                        if let Some(phys) = e.physics.as_mut() {
                            phys.velocity.x = 0.0;
                        }
                    } else {
                        e.transform.pos.y += oyv;
                        r = entity_aabb(e);
                        if kill_vy {
                            if let Some(phys) = e.physics.as_mut() {
                                if (oyv > 0.0 && phys.velocity.y < 0.0) || (oyv < 0.0 && phys.velocity.y > 0.0) {
                                    phys.velocity.y = 0.0;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

pub fn resolve_tilemaps(scene: &mut Scene) {
    let layers: Vec<TilemapLayer> = scene.tilemaps.clone();
    for e in &mut scene.entities {
        resolve_entity_against_tiles(e, &layers);
    }
}

pub fn clamp_camera_to_active_room(scene: &mut Scene) {
    let tid = scene
        .cameras
        .iter()
        .find(|c| c.active)
        .and_then(|c| c.target_entity_id);
    let Some(tid) = tid else {
        return;
    };
    let Some(t) = scene.entities.iter().find(|e| e.id == tid) else {
        return;
    };
    let px = t.transform.pos.x;
    let py = t.transform.pos.y;
    for room in &scene.rooms {
        if px >= room.x && px <= room.x + room.w && py >= room.y && py <= room.y + room.h {
            if room.camera_max_x > room.camera_min_x {
                scene.camera_center.x = scene
                    .camera_center
                    .x
                    .clamp(room.camera_min_x, room.camera_max_x);
            }
            if room.camera_max_y > room.camera_min_y {
                scene.camera_center.y = scene
                    .camera_center
                    .y
                    .clamp(room.camera_min_y, room.camera_max_y);
            }
            break;
        }
    }
}
