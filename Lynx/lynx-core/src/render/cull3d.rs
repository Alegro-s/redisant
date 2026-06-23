//! M14b: frustum + CPU Hi-Z occlusion (coarse, без GPU readback).

use crate::math::{Aabb3, Mat4, Vec3};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct CullStats {
    pub frustum_culled: u32,
    pub hiz_culled: u32,
}

#[derive(Clone, Copy, Debug)]
pub struct CullSettings {
    pub frustum: bool,
    pub hi_z: bool,
    pub hi_z_size: u32,
    pub depth_bias: f32,
}

impl Default for CullSettings {
    fn default() -> Self {
        Self {
            frustum: true,
            hi_z: true,
            hi_z_size: 64,
            depth_bias: 0.002,
        }
    }
}

/// Низкое разрешение: min distance to camera per cell (CPU Hi-Z).
pub struct HiZBuffer {
    size: u32,
    depths: Vec<f32>,
}

impl HiZBuffer {
    pub fn new(size: u32) -> Self {
        let size = size.clamp(16, 256);
        let n = (size * size) as usize;
        Self {
            size,
            depths: vec![f32::INFINITY; n],
        }
    }

    pub fn clear(&mut self) {
        self.depths.fill(f32::INFINITY);
    }

    pub fn rasterize_aabb(&mut self, view_proj: Mat4, camera: Vec3, aabb: &Aabb3) {
        let Some((x0, y0, x1, y1)) = screen_rect(view_proj, aabb, self.size) else {
            return;
        };
        let depth = closest_distance_to_camera(camera, aabb);
        for y in y0..=y1 {
            for x in x0..=x1 {
                let i = (y * self.size + x) as usize;
                if i < self.depths.len() {
                    self.depths[i] = self.depths[i].min(depth);
                }
            }
        }
    }

    /// `true` если AABB полностью за уже зарегистрированными occluder (дальше от камеры).
    pub fn is_occluded(&self, view_proj: Mat4, camera: Vec3, aabb: &Aabb3, depth_bias: f32) -> bool {
        let Some((x0, y0, x1, y1)) = screen_rect(view_proj, aabb, self.size) else {
            return false;
        };
        let depth = closest_distance_to_camera(camera, aabb);
        let mut covered = false;
        for y in y0..=y1 {
            for x in x0..=x1 {
                let i = (y * self.size + x) as usize;
                if i >= self.depths.len() {
                    continue;
                }
                let occluder = self.depths[i];
                if !occluder.is_finite() {
                    return false;
                }
                covered = true;
                if depth < occluder + depth_bias {
                    return false;
                }
            }
        }
        covered
    }
}

pub fn object_world_aabb(obj: &crate::scene3d::Lynx3dObject) -> Aabb3 {
    let he = Vec3::new(
        obj.half_extents[0].max(0.01),
        obj.half_extents[1].max(0.01),
        obj.half_extents[2].max(0.01),
    );
    let local = Aabb3::from_center_half_extents(Vec3::ZERO, he);
    let model = Mat4::model_trs(obj.position, obj.rotation_euler_deg, obj.scale);
    local.transform_by(model)
}

/// Стены комнаты как occluder для Hi-Z (не весь объём room).
pub fn room_occluder_aabbs(room: &crate::scene3d::Lynx3dRoom) -> Vec<Aabb3> {
    let cx = room.center[0];
    let cy = room.center[1];
    let cz = room.center[2];
    let hw = room.width * 0.5;
    let hh = room.height * 0.5;
    let hd = room.depth * 0.5;
    let thick = 0.15;
    // Только задняя стена — боковые AABB дают ложные Hi-Z при orbit-камере.
    vec![Aabb3::from_center_half_extents(
        Vec3::new(cx, cy, cz - hd),
        Vec3::new(hw * 0.98, hh * 0.98, thick),
    )]
}

pub fn room_world_aabb(room: &crate::scene3d::Lynx3dRoom) -> Aabb3 {
    let cx = room.center[0];
    let cy = room.center[1];
    let cz = room.center[2];
    Aabb3::from_center_half_extents(
        Vec3::new(cx, cy, cz),
        Vec3::new(room.width * 0.5, room.height * 0.5, room.depth * 0.5),
    )
}

pub fn terrain_world_aabb(terrain: &crate::scene3d::Lynx3dTerrain) -> Aabb3 {
    Aabb3::from_center_half_extents(
        Vec3::new(terrain.center[0], terrain.center[1], terrain.center[2]),
        Vec3::new(
            terrain.size[0] * 0.5,
            terrain.size[1] * 0.5,
            terrain.size[2] * 0.5,
        ),
    )
}

fn closest_distance_to_camera(camera: Vec3, aabb: &Aabb3) -> f32 {
    aabb.corners()
        .iter()
        .map(|p| {
            let d = *p - camera;
            (d.x * d.x + d.y * d.y + d.z * d.z).sqrt()
        })
        .fold(f32::INFINITY, f32::min)
}

fn screen_rect(view_proj: Mat4, aabb: &Aabb3, buffer_size: u32) -> Option<(u32, u32, u32, u32)> {
    let mut min_x = f32::INFINITY;
    let mut max_x = f32::NEG_INFINITY;
    let mut min_y = f32::INFINITY;
    let mut max_y = f32::NEG_INFINITY;
    let mut any = false;
    for p in aabb.corners() {
        let clip = clip_coords(view_proj, p);
        if clip.3 <= 0.0 {
            continue;
        }
        any = true;
        let inv_w = 1.0 / clip.3;
        let ndc_x = clip.0 * inv_w;
        let ndc_y = clip.1 * inv_w;
        min_x = min_x.min(ndc_x);
        max_x = max_x.max(ndc_x);
        min_y = min_y.min(ndc_y);
        max_y = max_y.max(ndc_y);
    }
    if !any {
        return None;
    }
    let sz = buffer_size.max(1) as f32;
    let x0 = ((min_x * 0.5 + 0.5) * sz).floor().max(0.0) as u32;
    let x1 = ((max_x * 0.5 + 0.5) * sz).ceil().min(sz - 1.0) as u32;
    let y0 = ((1.0 - (max_y * 0.5 + 0.5)) * sz).floor().max(0.0) as u32;
    let y1 = ((1.0 - (min_y * 0.5 + 0.5)) * sz).ceil().min(sz - 1.0) as u32;
    if x0 > x1 || y0 > y1 {
        return None;
    }
    Some((x0, y0, x1, y1))
}

fn clip_coords(m: Mat4, p: Vec3) -> (f32, f32, f32, f32) {
    let v = &m.m;
    let x = v[0] * p.x + v[4] * p.y + v[8] * p.z + v[12];
    let y = v[1] * p.x + v[5] * p.y + v[9] * p.z + v[13];
    let z = v[2] * p.x + v[6] * p.y + v[10] * p.z + v[14];
    let w = v[3] * p.x + v[7] * p.y + v[11] * p.z + v[15];
    (x, y, z, w)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::math::Frustum;
    use crate::scene3d::{Lynx3dObject, Lynx3dRoom};

    fn test_view_proj() -> Mat4 {
        let view = Mat4::look_at_rh(
            Vec3::new(0.0, 2.0, 14.0),
            Vec3::new(0.0, 2.0, 0.0),
            Vec3::new(0.0, 1.0, 0.0),
        );
        let proj = Mat4::perspective_rh(60.0, 1.0, 0.1, 200.0);
        proj.multiply(view)
    }

    #[test]
    fn hiz_occludes_behind_wall() {
        let vp = test_view_proj();
        let room = Lynx3dRoom {
            width: 8.0,
            height: 4.0,
            depth: 8.0,
            center: [0.0, 2.0, 0.0],
        };
        let mut hiz = HiZBuffer::new(64);
        let cam = Vec3::new(0.0, 2.0, 14.0);
        for wall in room_occluder_aabbs(&room) {
            hiz.rasterize_aabb(vp, cam, &wall);
        }
        let hidden = Aabb3::from_center_half_extents(Vec3::new(0.0, 2.0, -5.0), Vec3::new(0.35, 0.35, 0.35));
        assert!(hiz.is_occluded(vp, cam, &hidden, 0.05));
        let visible = Aabb3::from_center_half_extents(Vec3::new(0.0, 2.0, 2.0), Vec3::new(0.4, 0.4, 0.4));
        assert!(!hiz.is_occluded(vp, cam, &visible, 0.05));
        let _ = room;
    }

    #[test]
    fn object_aabb_behind_camera_frustum_fails() {
        let vp = test_view_proj();
        let frustum = Frustum::from_view_proj(&vp);
        let obj = Lynx3dObject {
            id: "far".into(),
            mesh_path: None,
            position: [0.0, 2.0, 30.0],
            rotation_euler_deg: [0.0, 0.0, 0.0],
            scale: [1.0, 1.0, 1.0],
            half_extents: [0.5, 0.5, 0.5],
            color_rgba: 0xFFFFFFFF,
            metallic: 0.0,
            roughness: 0.5,
            albedo_texture: None,
            normal_texture: None,
            metallic_roughness_texture: None,
            animation_clip: None,
            animation_time_sec: 0.0,
            is_static: false,
            restitution: 0.0,
            friction: 0.5,
        };
        assert!(!frustum.intersects_aabb(&object_world_aabb(&obj)));
    }
}
