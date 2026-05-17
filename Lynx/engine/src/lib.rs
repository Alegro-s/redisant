mod behavior_tree;
mod platformer;
mod unity_like;

pub use behavior_tree::{BehaviorTree, BtNode, BtState, EntitySnap};
pub use platformer::{
    AnimConditionKind, AnimRule, AnimStateMachine, GamepadState, PatrolAi, PlatformerInputLatch,
    PlatformerMotor, RoomZone, TileChunk, TilemapLayer, TILE_EMPTY, TILE_ONE_WAY, TILE_SLOPE_45_L,
    TILE_SLOPE_45_R, TILE_SOLID,
};
pub use unity_like::{AudioMixerState, AudioSource2D, Camera2D, EntityAnimator};

use mlua::Lua;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::ffi::{c_void, CString};
use std::ptr;
use std::sync::{Arc, Mutex};

#[repr(C)]
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}
impl Vec2 {
    pub const ZERO: Self = Self { x: 0.0, y: 0.0 };
    pub fn new(x: f32, y: f32) -> Self { Self { x, y } }

    #[inline]
    pub fn length(self) -> f32 {
        (self.x * self.x + self.y * self.y).sqrt()
    }

    #[inline]
    pub fn length_squared(self) -> f32 {
        self.x * self.x + self.y * self.y
    }

    #[inline]
    pub fn normalized(self) -> Self {
        let len = self.length();
        if len <= f32::EPSILON {
            Self::ZERO
        } else {
            Self {
                x: self.x / len,
                y: self.y / len,
            }
        }
    }

    #[inline]
    pub fn dot(self, other: Self) -> f32 {
        self.x * other.x + self.y * other.y
    }

    #[inline]
    pub fn distance(a: Self, b: Self) -> f32 {
        (a - b).length()
    }

    #[inline]
    pub fn lerp(a: Self, b: Self, t: f32) -> Self {
        Self {
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t,
        }
    }
}

impl std::ops::Sub for Vec2 {
    type Output = Self;
    fn sub(self, rhs: Self) -> Self {
        Self {
            x: self.x - rhs.x,
            y: self.y - rhs.y,
        }
    }
}

impl Default for Vec2 {
    fn default() -> Self {
        Self::ZERO
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct Color {
    pub r: f32, pub g: f32, pub b: f32, pub a: f32,
}
impl Color {
    pub const WHITE: Self = Self { r: 1.0, g: 1.0, b: 1.0, a: 1.0 };
    pub const RED: Self = Self { r: 1.0, g: 0.0, b: 0.0, a: 1.0 };
}

mod io_vec2 {
    use super::Vec2;
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    #[derive(Serialize, Deserialize)]
    struct Vec2Surrogate { x: f32, y: f32 }
    pub fn serialize<S>(v: &Vec2, s: S) -> Result<S::Ok, S::Error> where S: Serializer {
        Vec2Surrogate { x: v.x, y: v.y }.serialize(s)
    }
    pub fn deserialize<'de, D>(d: D) -> Result<Vec2, D::Error> where D: Deserializer<'de> {
        let sur = Vec2Surrogate::deserialize(d)?;
        Ok(Vec2::new(sur.x, sur.y))
    }
}

#[derive(Clone, Copy, Serialize, Deserialize)]
pub struct Transform {
    #[serde(with = "io_vec2")]
    pub pos: Vec2,
    #[serde(with = "io_vec2")]
    pub size: Vec2,
    pub rot: f32,
}
impl Default for Transform {
    fn default() -> Self { Self { pos: Vec2::ZERO, size: Vec2::new(40.0, 40.0), rot: 0.0 } }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
#[serde(rename_all = "lowercase")]
pub enum ColliderShape {
    #[default]
    Aabb,
    Circle,
}

fn default_collision_layer() -> u32 { 1 }
fn default_collision_mask() -> u32 { 0xFFFF }

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct LogicGrid {
    pub w: u32,
    pub h: u32,
    #[serde(default)]
    pub cells: Vec<i32>,
}

impl LogicGrid {
    fn ensure_size(w: u32, h: u32) -> Self {
        let n = (w.saturating_mul(h)) as usize;
        Self {
            w,
            h,
            cells: vec![0; n.max(1)],
        }
    }

    fn idx(&self, x: i32, y: i32) -> Option<usize> {
        if x < 0 || y < 0 {
            return None;
        }
        let x = x as u32;
        let y = y as u32;
        if x >= self.w || y >= self.h {
            return None;
        }
        Some((y * self.w + x) as usize)
    }

    pub fn get_cell(&self, x: i32, y: i32) -> i32 {
        self.idx(x, y).map(|i| self.cells[i]).unwrap_or(0)
    }

    pub fn set_cell(&mut self, x: i32, y: i32, v: i32) {
        if let Some(i) = self.idx(x, y) {
            self.cells[i] = v;
        }
    }

    pub fn resize_clear(&mut self, w: u32, h: u32) {
        *self = Self::ensure_size(w.max(1), h.max(1));
    }

    pub fn fill(&mut self, v: i32) {
        for c in &mut self.cells {
            *c = v;
        }
    }
}

#[derive(Clone, Copy, Serialize, Deserialize)]
pub struct PhysicsBody {
    #[serde(with = "io_vec2")]
    pub velocity: Vec2,
    pub mass: f32,
    pub is_static: bool,
    pub use_gravity: bool,
    pub bounciness: f32,
    #[serde(default)]
    pub shape: ColliderShape,
    #[serde(default = "default_collision_layer")]
    pub collision_layer: u32,
    #[serde(default = "default_collision_mask")]
    pub collision_mask: u32,
    #[serde(default)]
    pub is_trigger: bool,
    #[serde(default)]
    pub one_way: bool,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Default)]
pub struct TexRect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize, Default)]
pub struct SpriteAnim {
    pub frames: Vec<TexRect>,
    pub fps: f32,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, Default)]
pub struct VisualOffset2D {
    #[serde(default)]
    pub x: f32,
    #[serde(default)]
    pub y: f32,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SpriteData {
    pub color_hex: u32,
    pub texture_path: Option<String>,
    #[serde(default)]
    pub texture_width: Option<f32>,
    #[serde(default)]
    pub texture_height: Option<f32>,
    #[serde(default)]
    pub uv_rect: Option<TexRect>,
    #[serde(default)]
    pub animation: Option<SpriteAnim>,
    #[serde(default)]
    pub visual_offset: VisualOffset2D,
    #[serde(default)]
    pub visual_width: Option<f32>,
    #[serde(default)]
    pub visual_height: Option<f32>,
    #[serde(default)]
    pub sorting_layer: i32,
    #[serde(default)]
    pub order_in_layer: i32,
}
impl Default for SpriteData {
    fn default() -> Self {
        Self {
            color_hex: 0xFF808080,
            texture_path: None,
            texture_width: None,
            texture_height: None,
            uv_rect: None,
            animation: None,
            visual_offset: VisualOffset2D::default(),
            visual_width: None,
            visual_height: None,
            sorting_layer: 0,
            order_in_layer: 0,
        }
    }
}

#[derive(Clone, Serialize, Deserialize)]
pub struct LuaScript {
    pub code: String,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct Entity {
    pub id: usize,
    pub name: String,
    pub transform: Transform,
    pub sprite: SpriteData,
    pub physics: Option<PhysicsBody>,
    pub script: Option<LuaScript>,
    pub visible: bool,
    #[serde(default)]
    pub on_ground: bool,
    #[serde(default)]
    pub parent_id: Option<usize>,
    #[serde(default)]
    pub animator: Option<EntityAnimator>,
    #[serde(default)]
    pub audio_source: Option<AudioSource2D>,
    #[serde(skip, default)]
    pub world_pos_cache: Vec2,
    #[serde(default)]
    pub platformer_motor: Option<platformer::PlatformerMotor>,
    #[serde(default)]
    pub patrol_ai: Option<platformer::PatrolAi>,
    #[serde(default)]
    pub anim_state_machine: Option<platformer::AnimStateMachine>,
    #[serde(default)]
    pub animation_clips: HashMap<String, SpriteAnim>,
    #[serde(default)]
    pub behavior_tree: Option<behavior_tree::BehaviorTree>,
    #[serde(skip, default)]
    pub bt_state: behavior_tree::BtState,
}
impl Entity {
    pub fn new(id: usize, name: &str, pos: Vec2, color: Color) -> Self {
        Self {
            id,
            name: name.to_string(),
            transform: Transform { pos, ..Default::default() },
            sprite: SpriteData {
                color_hex: color_to_hex(color),
                ..Default::default()
            },
            physics: None,
            script: None,
            visible: true,
            on_ground: false,
            parent_id: None,
            animator: None,
            audio_source: None,
            world_pos_cache: Vec2::ZERO,
            platformer_motor: None,
            patrol_ai: None,
            anim_state_machine: None,
            animation_clips: HashMap::new(),
            behavior_tree: None,
            bt_state: behavior_tree::BtState::default(),
        }
    }
    pub fn color(&self) -> Color { hex_to_color(self.sprite.color_hex) }
    pub fn duplicate(&self, new_id: usize) -> Self {
        let mut new = self.clone();
        new.id = new_id;
        new.name = format!("{} Copy", self.name);
        new.transform.pos.x += 40.0;
        new.transform.pos.y -= 40.0;
        new.on_ground = false;
        new
    }
}

#[derive(Clone, Copy, Default, Debug)]
pub struct KeyState {
    pub w: bool,
    pub a: bool,
    pub s: bool,
    pub d: bool,
    pub space: bool,
}
impl KeyState {
    pub fn set_key(&mut self, key: char, pressed: bool) {
        match key {
            'w' | 'W' => self.w = pressed,
            'a' | 'A' => self.a = pressed,
            's' | 'S' => self.s = pressed,
            'd' | 'D' => self.d = pressed,
            ' ' => self.space = pressed,
            _ => {}
        }
    }
}

fn is_static_body(e: &Entity) -> bool {
    e.physics.as_ref().map_or(true, |p| p.is_static)
}

fn is_dynamic_body(e: &Entity) -> bool {
    e.physics.as_ref().map(|p| !p.is_static).unwrap_or(false)
}

fn default_key_state_arc() -> Arc<Mutex<KeyState>> {
    Arc::new(Mutex::new(KeyState::default()))
}

fn default_string_queue_arc() -> Arc<Mutex<Vec<String>>> {
    Arc::new(Mutex::new(Vec::new()))
}

fn default_gamepad_arc() -> Arc<Mutex<platformer::GamepadState>> {
    Arc::new(Mutex::new(platformer::GamepadState::default()))
}

fn default_platformer_latch_arc() -> Arc<Mutex<platformer::PlatformerInputLatch>> {
    Arc::new(Mutex::new(platformer::PlatformerInputLatch::default()))
}

#[derive(Serialize, Deserialize)]
pub struct Scene {
    pub entities: Vec<Entity>,
    pub next_id: usize,
    #[serde(default)]
    pub cameras: Vec<Camera2D>,
    #[serde(with = "io_vec2", default)]
    pub camera_center: Vec2,
    #[serde(default)]
    pub audio_mixer: AudioMixerState,
    #[serde(default)]
    pub tilemaps: Vec<platformer::TilemapLayer>,
    #[serde(default)]
    pub rooms: Vec<platformer::RoomZone>,
    #[serde(default)]
    pub logic_grids: HashMap<String, LogicGrid>,
    #[serde(skip, default = "default_key_state_arc")]
    pub key_state: Arc<Mutex<KeyState>>,
    #[serde(skip, default = "default_gamepad_arc")]
    pub gamepad: Arc<Mutex<platformer::GamepadState>>,
    #[serde(skip, default = "default_platformer_latch_arc")]
    pub platformer_latch: Arc<Mutex<platformer::PlatformerInputLatch>>,
    #[serde(skip, default = "default_string_queue_arc")]
    pub sound_queue: Arc<Mutex<Vec<String>>>,
    #[serde(skip, default = "default_string_queue_arc")]
    pub debug_log: Arc<Mutex<Vec<String>>>,
    #[serde(skip, default = "default_trigger_pairs_prev")]
    pub trigger_pairs_prev: HashSet<(usize, usize)>,
}

fn default_trigger_pairs_prev() -> HashSet<(usize, usize)> {
    HashSet::new()
}

impl Scene {
    pub fn new() -> Self {
        Self {
            entities: vec![],
            next_id: 0,
            cameras: vec![Camera2D::default()],
            camera_center: Vec2::ZERO,
            audio_mixer: AudioMixerState::default(),
            tilemaps: Vec::new(),
            rooms: Vec::new(),
            logic_grids: HashMap::new(),
            key_state: Arc::new(Mutex::new(KeyState::default())),
            gamepad: default_gamepad_arc(),
            platformer_latch: default_platformer_latch_arc(),
            sound_queue: default_string_queue_arc(),
            debug_log: default_string_queue_arc(),
            trigger_pairs_prev: HashSet::new(),
        }
    }
    pub fn add_entity(&mut self, name: &str, pos: Vec2, color: Color) -> usize {
        let id = self.next_id;
        let mut new_entity = Entity::new(id, name, pos, color);
        if name != "Ground" {
            new_entity.physics = Some(PhysicsBody {
                velocity: Vec2::ZERO,
                mass: 1.0,
                is_static: false,
                use_gravity: true,
                bounciness: 0.5,
                shape: ColliderShape::Aabb,
                collision_layer: 1,
                collision_mask: 0xFFFF,
                is_trigger: false,
                one_way: false,
            });
        }
        self.entities.push(new_entity);
        self.next_id += 1;
        id
    }
    pub fn get_mut(&mut self, id: usize) -> Option<&mut Entity> {
        self.entities.iter_mut().find(|e| e.id == id)
    }
    pub fn get(&self, id: usize) -> Option<&Entity> {
        self.entities.iter().find(|e| e.id == id)
    }

    fn layers_collide(a: &PhysicsBody, b: &PhysicsBody) -> bool {
        a.collision_layer & b.collision_mask != 0 && b.collision_layer & a.collision_mask != 0
    }

    fn physics_substep_count(entities: &[Entity], dt: f32) -> usize {
        let mut max_ratio = 0.0f32;
        for e in entities {
            let Some(p) = e.physics.as_ref() else {
                continue;
            };
            if p.is_static {
                continue;
            }
            let speed = p.velocity.length() * dt;
            let half = e.transform.size.x.min(e.transform.size.y).max(4.0) * 0.35;
            let r = speed / half.max(1.0);
            max_ratio = max_ratio.max(r);
        }
        let n = max_ratio.ceil() as usize;
        n.clamp(1, 16)
    }

    pub fn update_physics(&mut self, dt: f32) {
        let n = Self::physics_substep_count(&self.entities, dt);
        let h = dt / n as f32;
        for _ in 0..n {
            self.update_physics_substep(h);
        }
        Self::update_grounded(&mut self.entities);
    }

    fn update_physics_substep(&mut self, dt: f32) {
        let gravity = Vec2::new(0.0, 900.0);
        for e in &mut self.entities {
            if let Some(phys) = &mut e.physics {
                if phys.is_static {
                    continue;
                }
                if phys.use_gravity {
                    phys.velocity.x += gravity.x * dt;
                    phys.velocity.y += gravity.y * dt;
                }
                e.transform.pos.x += phys.velocity.x * dt;
                e.transform.pos.y += phys.velocity.y * dt;
            }
        }
        let pairs = collision_candidate_pairs(&self.entities);
        let mut reactions: Vec<(usize, Vec2, bool)> = Vec::new();
        let entities_ref = &self.entities;
        for (i, j) in pairs {
            let (e1, e2) = (&entities_ref[i], &entities_ref[j]);
            let p1 = e1.physics.as_ref();
            let p2 = e2.physics.as_ref();
            let layers_ok = match (p1, p2) {
                (Some(a), Some(b)) => Self::layers_collide(a, b),
                (Some(a), None) => a.collision_layer & default_collision_mask() != 0,
                (None, Some(b)) => b.collision_layer & default_collision_mask() != 0,
                (None, None) => true,
            };
            if !layers_ok {
                continue;
            }
            let trigger_pair = p1.map(|x| x.is_trigger).unwrap_or(false)
                || p2.map(|x| x.is_trigger).unwrap_or(false);
            let Some(overlap) = collision_overlap(e1, e2) else { continue };
            if trigger_pair {
                continue;
            }
            let is_s1 = is_static_body(e1);
            let is_s2 = is_static_body(e2);
            if is_s2 && !is_s1 {
                if p2.map(|p| p.one_way).unwrap_or(false) {
                    let r1 = entity_aabb(e1);
                    let r2 = entity_aabb(e2);
                    let bottom = r1.y + r1.h;
                    let top = r2.y;
                    let vy = e1.physics.as_ref().map(|p| p.velocity.y).unwrap_or(0.0);
                    if vy <= 0.0 && bottom > top + 8.0 {
                        continue;
                    }
                }
            }
            if is_s1 && !is_s2 {
                if p1.map(|p| p.one_way).unwrap_or(false) {
                    let r1 = entity_aabb(e1);
                    let r2 = entity_aabb(e2);
                    let bottom = r2.y + r2.h;
                    let top = r1.y;
                    let vy = e2.physics.as_ref().map(|p| p.velocity.y).unwrap_or(0.0);
                    if vy <= 0.0 && bottom > top + 8.0 {
                        continue;
                    }
                }
            }
            let total_mass = e1.physics.map_or(0.0, |p| p.mass) + e2.physics.map_or(0.0, |p| p.mass);
            let overlap_x = overlap.0;
            let overlap_y = overlap.1;
            if overlap_x <= 0.0 || overlap_y <= 0.0 {
                continue;
            }
            if overlap_x < overlap_y {
                let push = overlap_x;
                let r1 = entity_aabb(e1);
                let r2 = entity_aabb(e2);
                let dir = if r1.x + r1.w / 2.0 < r2.x + r2.w / 2.0 { -1.0 } else { 1.0 };
                if !is_s1 {
                    let ratio = if is_s2 { 1.0 } else { e2.physics.map_or(0.5, |p| p.mass) / total_mass };
                    reactions.push((i, Vec2::new(dir * push * ratio, 0.0), true));
                }
                if !is_s2 {
                    let ratio = if is_s1 { 1.0 } else { e1.physics.map_or(0.5, |p| p.mass) / total_mass };
                    reactions.push((j, Vec2::new(-dir * push * ratio, 0.0), true));
                }
            } else {
                let push = overlap_y;
                let r1 = entity_aabb(e1);
                let r2b = entity_aabb(e2);
                let dir = if r1.y + r1.h / 2.0 < r2b.y + r2b.h / 2.0 { -1.0 } else { 1.0 };
                if !is_s1 {
                    let ratio = if is_s2 { 1.0 } else { e2.physics.map_or(0.5, |p| p.mass) / total_mass };
                    reactions.push((i, Vec2::new(0.0, dir * push * ratio), false));
                }
                if !is_s2 {
                    let ratio = if is_s1 { 1.0 } else { e1.physics.map_or(0.5, |p| p.mass) / total_mass };
                    reactions.push((j, Vec2::new(0.0, -dir * push * ratio), false));
                }
            }
        }
        for (idx, adj, is_x) in reactions {
            if let Some(e) = self.entities.get_mut(idx) {
                if let Some(phys) = &mut e.physics {
                    e.transform.pos.x += adj.x;
                    e.transform.pos.y += adj.y;
                    if is_x {
                        phys.velocity.x *= -phys.bounciness;
                    } else {
                        if (adj.y > 0.0 && phys.velocity.y < 0.0) || (adj.y < 0.0 && phys.velocity.y > 0.0) {
                            phys.velocity.y = 0.0;
                        } else {
                            phys.velocity.y *= -phys.bounciness;
                        }
                        phys.velocity.x *= 0.95;
                    }
                }
            }
        }
    }

    pub fn process_trigger_events(&mut self) {
        let current = collect_trigger_overlap_pairs_by_entity_id(&self.entities);
        let prev = std::mem::take(&mut self.trigger_pairs_prev);
        self.trigger_pairs_prev = current.clone();
        let log_q = self.debug_log.clone();
        let entities = &self.entities;
        for &(a_id, b_id) in current.difference(&prev) {
            dispatch_trigger_pair(entities, a_id, b_id, "on_trigger_enter", &log_q);
        }
        for &(a_id, b_id) in prev.difference(&current) {
            dispatch_trigger_pair(entities, a_id, b_id, "on_trigger_exit", &log_q);
        }
    }

    fn update_grounded(entities: &mut [Entity]) {
        let n = entities.len();
        let mut flags = vec![false; n];
        for i in 0..n {
            if !is_dynamic_body(&entities[i]) {
                continue;
            }
            let e = &entities[i];
            let bottom = e.transform.pos.y + e.transform.size.y / 2.0;
            let left = e.transform.pos.x - e.transform.size.x / 2.0;
            let right = e.transform.pos.x + e.transform.size.x / 2.0;
            let vy = e.physics.as_ref().map(|p| p.velocity.y).unwrap_or(0.0);
            for j in 0..n {
                if i == j {
                    continue;
                }
                if !is_static_body(&entities[j]) {
                    continue;
                }
                let o = &entities[j];
                let top = o.transform.pos.y - o.transform.size.y / 2.0;
                let oleft = o.transform.pos.x - o.transform.size.x / 2.0;
                let oright = o.transform.pos.x + o.transform.size.x / 2.0;
                if bottom >= top - 4.0
                    && bottom <= top + 12.0
                    && right > oleft + 1.0
                    && left < oright - 1.0
                    && vy >= -120.0
                {
                    flags[i] = true;
                    break;
                }
            }
        }
        for i in 0..n {
            entities[i].on_ground = flags[i];
        }
    }

    pub fn update_scripts(&mut self, dt: f32) {
        let Scene {
            entities,
            logic_grids,
            key_state,
            gamepad,
            audio_mixer,
            sound_queue,
            debug_log,
            ..
        } = self;
        let ks = *key_state.lock().unwrap();
        let gp = *gamepad.lock().unwrap();
        let master_vol = audio_mixer.master_volume;
        let bus_volumes = audio_mixer.bus_volumes.clone();
        let sound_q = sound_queue.clone();
        let log_q = debug_log.clone();
        for i in 0..entities.len() {
            let Some(script) = entities[i].script.clone() else {
                continue;
            };
            let entity = &mut entities[i];
            run_entity_lua(
                entity,
                logic_grids,
                &script,
                dt,
                ks,
                gp,
                master_vol,
                &bus_volumes,
                sound_q.clone(),
                log_q.clone(),
            );
        }
    }
    pub fn step_animators(&mut self, dt: f32) {
        for e in &mut self.entities {
            if let Some(anim) = e.animator.as_mut() {
                anim.time += dt * anim.speed.max(0.001);
                if anim.looping && anim.time > 1.0e6 {
                    anim.time = 0.0;
                }
            }
        }
    }

    pub fn update_cameras_follow(&mut self, dt: f32) {
        for cam in &mut self.cameras {
            if !cam.active {
                continue;
            }
            let Some(tid) = cam.target_entity_id else { continue };
            let Some(target) = self.entities.iter().find(|e| e.id == tid) else {
                continue;
            };
            let ax = target.transform.pos.x + cam.offset.x;
            let ay = target.transform.pos.y + cam.offset.y;
            let mut cam_x = self.camera_center.x;
            let mut cam_y = self.camera_center.y;
            let dzx = cam.dead_zone_half_w;
            let dzy = cam.dead_zone_half_h;
            if (ax - cam_x).abs() > dzx {
                cam_x = ax - (ax - cam_x).signum() * dzx;
            }
            if (ay - cam_y).abs() > dzy {
                cam_y = ay - (ay - cam_y).signum() * dzy;
            }
            let k = (cam.smoothing * dt).min(1.0);
            self.camera_center.x += (cam_x - self.camera_center.x) * k;
            self.camera_center.y += (cam_y - self.camera_center.y) * k;
        }
    }

    pub fn propagate_transform_hierarchy(&mut self) {
        let n = self.entities.len();
        let mut world = vec![Vec2::ZERO; n];
        for i in 0..n {
            let id = self.entities[i].id;
            let mut p = self.entities[i].transform.pos;
            let mut cur = self.entities[i].parent_id;
            let mut guard = 0u8;
            while let Some(pid) = cur {
                if let Some(pe) = self.entities.iter().find(|e| e.id == pid) {
                    p.x += pe.transform.pos.x;
                    p.y += pe.transform.pos.y;
                    cur = pe.parent_id;
                } else {
                    break;
                }
                guard += 1;
                if guard > 64 {
                    break;
                }
            }
            if let Some(idx) = self.entities.iter().position(|e| e.id == id) {
                world[idx] = p;
            }
        }
        for i in 0..n {
            self.entities[i].world_pos_cache = world[i];
        }
    }

    pub fn play_clip_on_bus(&mut self, clip_path: &str, bus: &str, volume: f32) {
        let master = self.audio_mixer.master_volume;
        let bus_v = self.audio_mixer.bus_volumes.get(bus).copied().unwrap_or(1.0);
        let v = (volume * bus_v * master).clamp(0.0, 2.0);
        let line = format!("{}|{}|{}", bus, clip_path, v);
        self.sound_queue.lock().unwrap().push(line);
    }

    pub fn update(&mut self, dt: f32) {
        self.update_scripts(dt);
        behavior_tree::tick_behavior_trees(self, dt);
        platformer::step_patrol_ai(self, dt);
        platformer::step_platformer_motors(self, dt);
        platformer::step_anim_state_machines(self, dt);
        self.step_animators(dt);
        self.propagate_transform_hierarchy();
        self.update_physics(dt);
        platformer::resolve_tilemaps(self);
        self.process_trigger_events();
        self.update_cameras_follow(dt);
        platformer::clamp_camera_to_active_room(self);
    }

    pub fn drain_sounds_json(&self) -> String {
        let mut q = self.sound_queue.lock().unwrap();
        let v: Vec<String> = q.drain(..).collect();
        serde_json::to_string(&v).unwrap_or_else(|_| "[]".to_string())
    }

    pub fn drain_debug_log_json(&self) -> String {
        let mut q = self.debug_log.lock().unwrap();
        let v: Vec<String> = q.drain(..).collect();
        serde_json::to_string(&v).unwrap_or_else(|_| "[]".to_string())
    }
}

fn run_entity_lua(
    entity: &mut Entity,
    logic_grids: &mut HashMap<String, LogicGrid>,
    script: &LuaScript,
    dt: f32,
    ks: KeyState,
    gp: platformer::GamepadState,
    master_vol: f32,
    bus_volumes: &HashMap<String, f32>,
    sound_q: Arc<Mutex<Vec<String>>>,
    log_q: Arc<Mutex<Vec<String>>>,
) {
    let grids_ptr: *mut HashMap<String, LogicGrid> = logic_grids;
    let lua = Lua::new();
    let globals = lua.globals();
    let eid = entity.id;
    globals.set("id", eid as i32).unwrap();
    globals.set("dt", dt).unwrap();
    globals.set("x", entity.transform.pos.x).unwrap();
    globals.set("y", entity.transform.pos.y).unwrap();
    globals.set("key_w", ks.w).unwrap();
    globals.set("key_a", ks.a).unwrap();
    globals.set("key_s", ks.s).unwrap();
    globals.set("key_d", ks.d).unwrap();
    globals.set("key_space", ks.space).unwrap();
    globals.set("gp_lx", gp.stick_lx).unwrap();
    globals.set("gp_ly", gp.stick_ly).unwrap();
    globals.set("gp_a", gp.face_a).unwrap();
    globals.set("gp_b", gp.face_b).unwrap();
    globals.set("gp_dleft", gp.dpad_left).unwrap();
    globals.set("gp_dright", gp.dpad_right).unwrap();
    globals.set("on_ground", entity.on_ground).unwrap();
    if let Some(phys) = &entity.physics {
        globals.set("vx", phys.velocity.x).unwrap();
        globals.set("vy", phys.velocity.y).unwrap();
    }
    let set_position = lua
        .create_function(|lua, (x, y): (f32, f32)| {
            lua.globals().set("new_x", x).unwrap();
            lua.globals().set("new_y", y).unwrap();
            Ok(())
        })
        .unwrap();
    globals.set("set_position", set_position).unwrap();
    let set_velocity = lua
        .create_function(|lua, (vx, vy): (f32, f32)| {
            lua.globals().set("new_vx", vx).unwrap();
            lua.globals().set("new_vy", vy).unwrap();
            Ok(())
        })
        .unwrap();
    globals.set("set_velocity", set_velocity).unwrap();
    let sq = sound_q.clone();
    let play_sound = lua
        .create_function(move |_, path: String| {
            sq.lock().unwrap().push(path);
            Ok(())
        })
        .unwrap();
    globals.set("play_sound", play_sound).unwrap();
    let sq_bus = sound_q.clone();
    let bv = bus_volumes.clone();
    let play_sound_bus = lua
        .create_function(move |_, (path, bus, vol): (String, String, f32)| {
            let bus_v = bv.get(&bus).copied().unwrap_or(1.0);
            let v = (vol * bus_v * master_vol).clamp(0.0, 2.0);
            sq_bus.lock().unwrap().push(format!("{}|{}|{}", bus, path, v));
            Ok(())
        })
        .unwrap();
    globals.set("play_sound_bus", play_sound_bus).unwrap();
    let lq = log_q.clone();
    let nexus_log = lua
        .create_function(move |_, msg: String| {
            let line = format!("lua e{}: {}", eid, msg);
            let mut g = lq.lock().unwrap();
            g.push(line);
            if g.len() > 200 {
                g.remove(0);
            }
            Ok(())
        })
        .unwrap();
    globals.set("nexus_log", nexus_log).unwrap();

    let lerp_fn = lua
        .create_function(|_, (a, b, t): (f32, f32, f32)| Ok(a + (b - a) * t))
        .unwrap();
    globals.set("lerp", lerp_fn).unwrap();
    let clamp_fn = lua
        .create_function(|_, (v, lo, hi): (f32, f32, f32)| Ok(v.clamp(lo, hi)))
        .unwrap();
    globals.set("clamp", clamp_fn).unwrap();
    let dist_fn = lua
        .create_function(|_, (x1, y1, x2, y2): (f32, f32, f32, f32)| {
            let dx = x2 - x1;
            let dy = y2 - y1;
            Ok((dx * dx + dy * dy).sqrt())
        })
        .unwrap();
    globals.set("distance", dist_fn).unwrap();

    let grid_ensure = lua
        .create_function(move |_, (name, w, h): (String, u32, u32)| {
            unsafe {
                (*grids_ptr).insert(name, LogicGrid::ensure_size(w.max(1), h.max(1)));
            }
            Ok(())
        })
        .unwrap();
    globals.set("grid_ensure", grid_ensure).unwrap();

    let grid_get = lua
        .create_function(move |_, (name, x, y): (String, i32, i32)| {
            let v = unsafe {
                (*grids_ptr)
                    .get(&name)
                    .map(|g| g.get_cell(x, y))
                    .unwrap_or(0)
            };
            Ok(v)
        })
        .unwrap();
    globals.set("grid_get", grid_get).unwrap();

    let grid_set = lua
        .create_function(move |_, (name, x, y, v): (String, i32, i32, i32)| {
            unsafe {
                if let Some(g) = (*grids_ptr).get_mut(&name) {
                    g.set_cell(x, y, v);
                }
            }
            Ok(())
        })
        .unwrap();
    globals.set("grid_set", grid_set).unwrap();

    let grid_width = lua
        .create_function(move |_, name: String| {
            let w = unsafe {
                (*grids_ptr)
                    .get(&name)
                    .map(|g| g.w as i32)
                    .unwrap_or(0)
            };
            Ok(w)
        })
        .unwrap();
    globals.set("grid_width", grid_width).unwrap();

    let grid_height = lua
        .create_function(move |_, name: String| {
            let h = unsafe {
                (*grids_ptr)
                    .get(&name)
                    .map(|g| g.h as i32)
                    .unwrap_or(0)
            };
            Ok(h)
        })
        .unwrap();
    globals.set("grid_height", grid_height).unwrap();

    let grid_fill = lua
        .create_function(move |_, (name, v): (String, i32)| {
            unsafe {
                if let Some(g) = (*grids_ptr).get_mut(&name) {
                    g.fill(v);
                }
            }
            Ok(())
        })
        .unwrap();
    globals.set("grid_fill", grid_fill).unwrap();

    if let Err(e) = lua.load(&script.code).exec() {
        let mut g = log_q.lock().unwrap();
        g.push(format!("lua error e{}: {}", eid, e));
        if g.len() > 200 {
            g.remove(0);
        }
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
}

pub(crate) struct PhysRect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}
impl PhysRect {
    pub(crate) fn new(x: f32, y: f32, w: f32, h: f32) -> Self {
        Self { x, y, w, h }
    }
}

fn collision_candidate_pairs(entities: &[Entity]) -> Vec<(usize, usize)> {
    const CELL: f32 = 96.0;
    let mut buckets: HashMap<(i32, i32), Vec<usize>> = HashMap::new();
    for i in 0..entities.len() {
        let r = entity_aabb(&entities[i]);
        if !(r.w > 0.0 && r.h > 0.0) {
            continue;
        }
        let min_cx = (r.x / CELL).floor() as i32;
        let max_cx = ((r.x + r.w) / CELL).floor() as i32;
        let min_cy = (r.y / CELL).floor() as i32;
        let max_cy = ((r.y + r.h) / CELL).floor() as i32;
        for cx in min_cx..=max_cx {
            for cy in min_cy..=max_cy {
                buckets.entry((cx, cy)).or_default().push(i);
            }
        }
    }
    let mut pairs: HashSet<(usize, usize)> = HashSet::new();
    for v in buckets.values() {
        let n = v.len();
        for a in 0..n {
            for b in a + 1..n {
                let i = v[a];
                let j = v[b];
                if i < j {
                    pairs.insert((i, j));
                } else {
                    pairs.insert((j, i));
                }
            }
        }
    }
    let mut out: Vec<(usize, usize)> = pairs.into_iter().collect();
    out.sort_unstable();
    out
}

fn collect_trigger_overlap_pairs_by_entity_id(entities: &[Entity]) -> HashSet<(usize, usize)> {
    let mut out = HashSet::new();
    for (i, j) in collision_candidate_pairs(entities) {
        let e1 = &entities[i];
        let e2 = &entities[j];
        let p1 = e1.physics.as_ref();
        let p2 = e2.physics.as_ref();
        let layers_ok = match (p1, p2) {
            (Some(a), Some(b)) => Scene::layers_collide(a, b),
            (Some(a), None) => a.collision_layer & default_collision_mask() != 0,
            (None, Some(b)) => b.collision_layer & default_collision_mask() != 0,
            (None, None) => true,
        };
        if !layers_ok {
            continue;
        }
        let trig =
            p1.map(|x| x.is_trigger).unwrap_or(false) || p2.map(|x| x.is_trigger).unwrap_or(false);
        if !trig || collision_overlap(e1, e2).is_none() {
            continue;
        }
        let a = e1.id.min(e2.id);
        let b = e1.id.max(e2.id);
        out.insert((a, b));
    }
    out
}

fn dispatch_trigger_pair(
    entities: &[Entity],
    id_a: usize,
    id_b: usize,
    fn_name: &'static str,
    log_q: &Arc<Mutex<Vec<String>>>,
) {
    let ea = entities.iter().find(|e| e.id == id_a);
    let eb = entities.iter().find(|e| e.id == id_b);
    let (Some(ea), Some(eb)) = (ea, eb) else {
        return;
    };
    if ea.physics.as_ref().map(|p| p.is_trigger).unwrap_or(false) {
        if let Some(s) = ea.script.as_ref() {
            run_lua_trigger_callback(ea.id, &s.code, fn_name, eb.id as i64, log_q);
        }
    }
    if eb.physics.as_ref().map(|p| p.is_trigger).unwrap_or(false) {
        if let Some(s) = eb.script.as_ref() {
            run_lua_trigger_callback(eb.id, &s.code, fn_name, ea.id as i64, log_q);
        }
    }
}

fn run_lua_trigger_callback(
    self_id: usize,
    code: &str,
    fn_name: &str,
    other_id: i64,
    log_q: &Arc<Mutex<Vec<String>>>,
) {
    let lua = Lua::new();
    let globals = lua.globals();
    let _ = globals.set("id", self_id as i64);
    let _ = globals.set("other_id", other_id);
    if let Err(e) = lua.load(code).exec() {
        let mut g = log_q.lock().unwrap();
        g.push(format!("trigger lua load e{self_id}: {e}"));
        while g.len() > 200 {
            g.remove(0);
        }
        return;
    }
    if let Ok(f) = globals.get::<mlua::Function>(fn_name) {
        if let Err(e) = f.call::<()>(()) {
            let mut g = log_q.lock().unwrap();
            g.push(format!("trigger {fn_name} e{self_id}: {e}"));
            while g.len() > 200 {
                g.remove(0);
            }
        }
    }
}

pub(crate) fn entity_aabb(e: &Entity) -> PhysRect {
    PhysRect::new(
        e.transform.pos.x - e.transform.size.x / 2.0,
        e.transform.pos.y - e.transform.size.y / 2.0,
        e.transform.size.x,
        e.transform.size.y,
    )
}

fn entity_circle(e: &Entity) -> (f32, f32, f32) {
    let r = e.transform.size.x.min(e.transform.size.y) * 0.5;
    (e.transform.pos.x, e.transform.pos.y, r)
}

fn collision_overlap(e1: &Entity, e2: &Entity) -> Option<(f32, f32)> {
    let s1 = e1.physics.as_ref().map(|p| p.shape).unwrap_or(ColliderShape::Aabb);
    let s2 = e2.physics.as_ref().map(|p| p.shape).unwrap_or(ColliderShape::Aabb);
    match (s1, s2) {
        (ColliderShape::Aabb, ColliderShape::Aabb) => {
            let a = entity_aabb(e1);
            let b = entity_aabb(e2);
            aabb_aabb_overlap(&a, &b)
        }
        (ColliderShape::Circle, ColliderShape::Circle) => {
            let (x1, y1, r1) = entity_circle(e1);
            let (x2, y2, r2) = entity_circle(e2);
            circle_circle_overlap(x1, y1, r1, x2, y2, r2)
        }
        (ColliderShape::Circle, ColliderShape::Aabb) => {
            let (cx, cy, r) = entity_circle(e1);
            let b = entity_aabb(e2);
            circle_aabb_overlap(cx, cy, r, &b)
        }
        (ColliderShape::Aabb, ColliderShape::Circle) => {
            let (cx, cy, r) = entity_circle(e2);
            let b = entity_aabb(e1);
            circle_aabb_overlap(cx, cy, r, &b)
        }
    }
}

fn aabb_aabb_overlap(a: &PhysRect, b: &PhysRect) -> Option<(f32, f32)> {
    if a.x >= b.x + b.w || a.x + a.w <= b.x || a.y >= b.y + b.h || a.y + a.h <= b.y {
        return None;
    }
    let dx = (a.x + a.w / 2.0 - (b.x + b.w / 2.0)).abs();
    let dy = (a.y + a.h / 2.0 - (b.y + b.h / 2.0)).abs();
    let ox = (a.w + b.w) / 2.0 - dx;
    let oy = (a.h + b.h) / 2.0 - dy;
    Some((ox.max(0.0), oy.max(0.0)))
}

fn circle_circle_overlap(x1: f32, y1: f32, r1: f32, x2: f32, y2: f32, r2: f32) -> Option<(f32, f32)> {
    let dx = x1 - x2;
    let dy = y1 - y2;
    let dist = (dx * dx + dy * dy).sqrt();
    let pen = r1 + r2 - dist;
    if pen <= 0.0 {
        return None;
    }
    Some((pen.abs(), pen.abs()))
}

fn circle_aabb_overlap(cx: f32, cy: f32, r: f32, b: &PhysRect) -> Option<(f32, f32)> {
    let px = cx.clamp(b.x, b.x + b.w);
    let py = cy.clamp(b.y, b.y + b.h);
    let dx = cx - px;
    let dy = cy - py;
    let d2 = dx * dx + dy * dy;
    if d2 >= r * r {
        return None;
    }
    let pen = r - d2.sqrt();
    Some((pen.max(1.0), pen.max(1.0)))
}

fn color_to_hex(c: Color) -> u32 {
    ((c.r * 255.0) as u32) << 24 | ((c.g * 255.0) as u32) << 16 | ((c.b * 255.0) as u32) << 8 | ((c.a * 255.0) as u32)
}
fn hex_to_color(hex: u32) -> Color {
    Color {
        r: ((hex >> 24) & 0xFF) as f32 / 255.0,
        g: ((hex >> 16) & 0xFF) as f32 / 255.0,
        b: ((hex >> 8) & 0xFF) as f32 / 255.0,
        a: (hex & 0xFF) as f32 / 255.0,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_create() -> *mut c_void {
    Box::into_raw(Box::new(Scene::new())) as *mut c_void
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_destroy(ptr: *mut c_void) {
    if !ptr.is_null() { unsafe { drop(Box::from_raw(ptr as *mut Scene)); } }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_add_entity(
    ptr: *mut c_void, name: *const std::os::raw::c_char,
    px: f32, py: f32, cr: f32, cg: f32, cb: f32, ca: f32,
) -> usize {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        let name = std::ffi::CStr::from_ptr(name).to_str().unwrap_or("Unnamed");
        scene.add_entity(name, Vec2::new(px, py), Color { r: cr, g: cg, b: cb, a: ca })
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_set_script(ptr: *mut c_void, id: usize, script_ptr: *const std::os::raw::c_char) -> bool {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        let script = match std::ffi::CStr::from_ptr(script_ptr).to_str() {
            Ok(s) => s,
            Err(_) => return false,
        };
        if let Some(entity) = scene.get_mut(id) {
            entity.script = Some(LuaScript { code: script.to_string() });
            true
        } else {
            false
        }
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_update(ptr: *mut c_void, dt: f32) {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        scene.update(dt);
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_to_json(ptr: *const c_void) -> *mut std::os::raw::c_char {
    unsafe {
        let scene = &*(ptr as *const Scene);
        match serde_json::to_string(scene) {
            Ok(json) => CString::new(json).unwrap().into_raw(),
            Err(_) => ptr::null_mut(),
        }
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_from_json(json: *const std::os::raw::c_char) -> *mut c_void {
    unsafe {
        let json = match std::ffi::CStr::from_ptr(json).to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null_mut(),
        };
        match serde_json::from_str::<Scene>(json) {
            Ok(mut scene) => {
                scene.key_state = default_key_state_arc();
                scene.gamepad = default_gamepad_arc();
                scene.platformer_latch = default_platformer_latch_arc();
                scene.sound_queue = default_string_queue_arc();
                scene.debug_log = default_string_queue_arc();
                Box::into_raw(Box::new(scene)) as *mut c_void
            }
            Err(_) => ptr::null_mut(),
        }
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_set_entity_parent(ptr: *mut c_void, id: usize, parent_id: i64) {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        if let Some(e) = scene.get_mut(id) {
            e.parent_id = if parent_id < 0 {
                None
            } else {
                Some(parent_id as usize)
            };
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_set_primary_camera_target(ptr: *mut c_void, entity_id: i64) {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        if let Some(cam) = scene.cameras.first_mut() {
            cam.target_entity_id = if entity_id < 0 {
                None
            } else {
                Some(entity_id as usize)
            };
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_set_key(ptr: *mut c_void, key: u8, pressed: bool) {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        let key_char = key as char;
        let mut key_state = scene.key_state.lock().unwrap();
        key_state.set_key(key_char, pressed);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_set_gamepad(ptr: *mut c_void, lx: f32, ly: f32, buttons: u32) {
    unsafe {
        let scene = &mut *(ptr as *mut Scene);
        let mut g = scene.gamepad.lock().unwrap();
        g.stick_lx = lx.clamp(-1.0, 1.0);
        g.stick_ly = ly.clamp(-1.0, 1.0);
        g.face_a = buttons & 1 != 0;
        g.face_b = buttons & 2 != 0;
        g.dpad_left = buttons & 4 != 0;
        g.dpad_right = buttons & 8 != 0;
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_drain_sounds(ptr: *mut c_void) -> *mut std::os::raw::c_char {
    unsafe {
        let scene = &*(ptr as *mut Scene);
        let json = scene.drain_sounds_json();
        CString::new(json).unwrap().into_raw()
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn scene_drain_debug_log(ptr: *mut c_void) -> *mut std::os::raw::c_char {
    unsafe {
        let scene = &*(ptr as *mut Scene);
        let json = scene.drain_debug_log_json();
        CString::new(json).unwrap().into_raw()
    }
}
#[unsafe(no_mangle)]
pub extern "C" fn core_free_string(ptr: *mut std::os::raw::c_char) {
    if !ptr.is_null() { unsafe { drop(CString::from_raw(ptr)); } }
}
