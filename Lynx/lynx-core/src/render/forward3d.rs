//! Forward PBR-lite (directional + ambient + shadow map 2k) — M3.

use std::collections::HashMap;
use std::path::Path;

use crate::asset::glb_minimal::load_glb;
use crate::asset::glb_skin::{load_glb_skinned, SkinnedGlb};
use crate::asset::texture_rgba8::{load_rgba8_path, Rgba8Image};
use crate::math::{Frustum, Mat4, Vec3};
use crate::render::cull3d::{
    object_world_aabb, room_occluder_aabbs, room_world_aabb, terrain_world_aabb, CullSettings,
    CullStats, HiZBuffer,
};
use crate::render::mesh3d::Mesh3d;
use crate::render::terrain_mesh::{
    build_terrain_mesh, build_terrain_mesh_from_image, lod_segment_count, select_terrain_lod,
    terrain_camera_distance,
};
use crate::render::Color;
use crate::scene3d::{Lynx3dObject, Lynx3dRenderSettings, Lynx3dRoom, Lynx3dScene, Lynx3dTerrain};

pub const SHADOW_MAP_SIZE: u32 = 2048;

/// M12c: PCF + optional 2-cascade (направленный свет).
#[derive(Clone, Copy, Debug)]
pub struct ShadowSettings {
    /// 1 / SHADOW_MAP_SIZE
    pub texel_size: f32,
    pub depth_bias: f32,
    /// Минимальный множитель в тени (0.35 = мягкая penumbra).
    pub penumbra: f32,
    /// Дистанция от камеры (world units) для blend cascade0 → cascade1.
    pub cascade_split_distance: f32,
    pub enable_cascade: bool,
}

impl Default for ShadowSettings {
    fn default() -> Self {
        Self {
            texel_size: 1.0 / SHADOW_MAP_SIZE as f32,
            depth_bias: 0.002,
            penumbra: 0.35,
            cascade_split_distance: 10.0,
            enable_cascade: true,
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Vertex3d {
    pub pos: [f32; 3],
    pub normal: [f32; 3],
    pub uv: [f32; 2],
}

#[derive(Clone, Debug)]
pub struct Forward3DLight {
    pub direction: Vec3,
    pub ambient: [f32; 3],
}

#[derive(Clone, Debug)]
pub struct Forward3DDraw {
    pub model: Mat4,
    pub base_color: [f32; 4],
    pub metallic: f32,
    pub roughness: f32,
    pub mesh: Mesh3d,
    /// Stable key for GPU mesh cache (M12b).
    pub mesh_key: u64,
    /// Albedo RGBA uploaded to GPU when `Some` (M12b).
    pub albedo_image: Option<Rgba8Image>,
    /// Level 2: tangent-space normal map.
    pub normal_image: Option<Rgba8Image>,
    pub cast_shadow: bool,
}

#[derive(Clone, Debug)]
pub struct Forward3DFrame {
    pub view_proj: Mat4,
    pub light_view_proj: Mat4,
    /// Cascade 1 (широкий ortho); совпадает с cascade0 если `enable_cascade == false`.
    pub light_view_proj_c1: Mat4,
    pub camera_position: Vec3,
    pub shadow: ShadowSettings,
    pub light: Forward3DLight,
    pub render: Lynx3dRenderSettings,
    pub draws: Vec<Forward3DDraw>,
    pub cull_stats: CullStats,
}

impl Forward3DFrame {
    pub fn from_lynx3d_scene(
        scene: &Lynx3dScene,
        viewport_w: u32,
        viewport_h: u32,
        orbit_yaw_rad: f32,
        orbit_pitch_rad: f32,
    ) -> Self {
        Self::from_lynx3d_scene_with_assets(scene, viewport_w, viewport_h, orbit_yaw_rad, orbit_pitch_rad, None)
    }

    pub fn from_lynx3d_scene_with_assets(
        scene: &Lynx3dScene,
        viewport_w: u32,
        viewport_h: u32,
        orbit_yaw_rad: f32,
        orbit_pitch_rad: f32,
        project_root: Option<&Path>,
    ) -> Self {
        let aspect = viewport_w.max(1) as f32 / viewport_h.max(1) as f32;
        let cam = &scene.camera;
        let focus = scene
            .room
            .as_ref()
            .map(|r| Vec3::new(r.center[0], r.center[1], r.center[2]))
            .unwrap_or(Vec3::new(0.0, 2.0, 0.0));
        let dist = cam.orbit_distance.max(2.0);
        let pitch = orbit_pitch_rad.clamp(0.15, 1.4);
        let yaw = orbit_yaw_rad;
        let eye = Vec3::new(
            focus.x + dist * yaw.cos() * pitch.cos(),
            focus.y + dist * pitch.sin(),
            focus.z + dist * yaw.sin() * pitch.cos(),
        );
        let view = Mat4::look_at_rh(eye, focus, Vec3::new(0.0, 1.0, 0.0));
        let proj = Mat4::perspective_rh(cam.fov_y_deg, aspect, cam.near, cam.far);
        let view_proj = proj.multiply(view);

        let light_dir = Vec3::new(0.35, -0.85, 0.4).normalized();
        let shadow = ShadowSettings::default();
        let (light_view_proj, light_view_proj_c1) =
            compute_shadow_cascades(scene, light_dir, shadow.enable_cascade);

        let mut mesh_cache: HashMap<String, CachedGlb> = HashMap::new();
        let mut terrain_cache: HashMap<String, Mesh3d> = HashMap::new();
        let mut draws = Vec::new();
        let mut cull_stats = CullStats::default();
        let frustum = Frustum::from_view_proj(&view_proj);
        let cull = CullSettings {
            frustum: scene.culling.frustum,
            hi_z: scene.culling.hi_z,
            hi_z_size: scene.culling.hi_z_size,
            depth_bias: 0.002,
        };
        let mut hiz = if cull.hi_z {
            let mut buf = HiZBuffer::new(cull.hi_z_size);
            buf.clear();
            Some(buf)
        } else {
            None
        };

        if let Some(terrain) = &scene.terrain {
            let aabb = terrain_world_aabb(terrain);
            if !cull.frustum || frustum.intersects_aabb(&aabb) {
                draws.extend(terrain_draws(terrain, project_root, eye, &mut terrain_cache));
                if let Some(h) = &mut hiz {
                    h.rasterize_aabb(view_proj, eye, &aabb);
                }
            } else {
                cull_stats.frustum_culled += 1;
            }
        }

        if let Some(room) = &scene.room {
            let aabb = room_world_aabb(room);
            if !cull.frustum || frustum.intersects_aabb(&aabb) {
                draws.extend(room_draws(room));
                if let Some(h) = &mut hiz {
                    for occ in room_occluder_aabbs(room) {
                        h.rasterize_aabb(view_proj, eye, &occ);
                    }
                }
            } else {
                cull_stats.frustum_culled += 1;
            }
        }

        for obj in &scene.objects {
            let aabb = object_world_aabb(obj);
            if cull.frustum && !frustum.intersects_aabb(&aabb) {
                cull_stats.frustum_culled += 1;
                continue;
            }
            if let Some(h) = &mut hiz {
                if cull.hi_z && h.is_occluded(view_proj, eye, &aabb, cull.depth_bias) {
                    cull_stats.hiz_culled += 1;
                    continue;
                }
            }
            draws.push(object_draw(obj, project_root, &mut mesh_cache));
        }

        Self {
            view_proj,
            light_view_proj,
            light_view_proj_c1,
            camera_position: eye,
            shadow,
            light: Forward3DLight {
                direction: light_dir,
                ambient: scene.ambient_color,
            },
            render: scene.render,
            draws,
            cull_stats,
        }
    }

    pub fn draw_count(&self) -> usize {
        self.draws.len()
    }

    pub fn shadow_cast_count(&self) -> usize {
        self.draws.iter().filter(|d| d.cast_shadow).count()
    }
}

fn scene_focus(scene: &Lynx3dScene) -> (Vec3, f32) {
    let center = scene
        .room
        .as_ref()
        .map(|r| Vec3::new(r.center[0], r.center[1], r.center[2]))
        .unwrap_or(Vec3::new(0.0, 2.0, 0.0));
    let extent = scene
        .room
        .as_ref()
        .map(|r| r.width.max(r.depth).max(r.height) * 0.75 + 4.0)
        .unwrap_or(12.0);
    (center, extent)
}

fn compute_light_view_proj(scene: &Lynx3dScene, light_dir: Vec3, extent_scale: f32) -> Mat4 {
    let (center, extent) = scene_focus(scene);
    let ext = extent * extent_scale;
    let eye = center - light_dir * (ext * 2.0);
    let view = Mat4::look_at_rh(eye, center, Vec3::new(0.0, 1.0, 0.0));
    let ortho = Mat4::orthographic_rh(-ext, ext, -ext, ext, 0.5, ext * 4.0);
    ortho.multiply(view)
}

fn compute_shadow_cascades(
    scene: &Lynx3dScene,
    light_dir: Vec3,
    enable_cascade: bool,
) -> (Mat4, Mat4) {
    let c0 = compute_light_view_proj(scene, light_dir, 0.42);
    if enable_cascade {
        let c1 = compute_light_view_proj(scene, light_dir, 1.0);
        (c0, c1)
    } else {
        (c0, c0)
    }
}

enum CachedGlb {
    Static(Mesh3d),
    Skinned(SkinnedGlb),
}

fn resolve_mesh(
    path: Option<&str>,
    project_root: Option<&Path>,
    animation_clip: Option<&str>,
    animation_time_sec: f32,
    cache: &mut HashMap<String, CachedGlb>,
) -> Mesh3d {
    let Some(rel) = path else {
        return Mesh3d::unit_cube();
    };
    if let Some(entry) = cache.get(rel) {
        return match entry {
            CachedGlb::Static(m) => m.clone(),
            CachedGlb::Skinned(sk) => {
                let clip = animation_clip.and_then(|n| sk.clip_by_name(n));
                sk.mesh_at(clip, animation_time_sec)
            }
        };
    }
    let mesh = if let Some(root) = project_root {
        let full = root.join(rel);
        if full.is_file() {
            if let Ok(bytes) = std::fs::read(&full) {
                if let Some(sk) = load_glb_skinned(&bytes) {
                    let clip = animation_clip.and_then(|n| sk.clip_by_name(n));
                    let m = sk.mesh_at(clip, animation_time_sec);
                    cache.insert(rel.to_string(), CachedGlb::Skinned(sk));
                    return m;
                }
                if let Some(m) = load_glb(&bytes) {
                    cache.insert(rel.to_string(), CachedGlb::Static(m.clone()));
                    return m;
                }
            }
        }
        Mesh3d::unit_cube()
    } else {
        Mesh3d::unit_cube()
    };
    cache.insert(rel.to_string(), CachedGlb::Static(mesh.clone()));
    mesh
}

fn mesh_cache_key(mesh: &Mesh3d, path: Option<&str>) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut h = DefaultHasher::new();
    path.hash(&mut h);
    mesh.indices.len().hash(&mut h);
    mesh.positions.len().hash(&mut h);
    for p in mesh.positions.iter().take(12) {
        p.to_bits().hash(&mut h);
    }
    h.finish()
}

fn flat_terrain_fallback(size: [f32; 3], segments: u32) -> Mesh3d {
    let heights = vec![0.5f32; 4];
    build_terrain_mesh(&heights, 2, 2, size, segments, segments)
}

fn terrain_draws(
    terrain: &Lynx3dTerrain,
    project_root: Option<&Path>,
    camera_pos: Vec3,
    cache: &mut HashMap<String, Mesh3d>,
) -> Vec<Forward3DDraw> {
    let dist = terrain_camera_distance(camera_pos, terrain.center);
    let levels = terrain.clipmap_levels.max(1);
    let mut out = Vec::new();
    for ring in 0..levels {
        let lod = select_terrain_lod(
            dist + ring as f32 * terrain.lod_split_distance * 0.5,
            terrain.lod_split_distance,
            terrain.max_lod,
        );
        let seg = lod_segment_count(terrain.segments >> ring.min(2), lod);
        let cache_key = format!("{}:clip{ring}:lod{lod}:s{seg}", terrain.heightmap_path);
        let mesh = if let Some(m) = cache.get(&cache_key) {
            m.clone()
        } else {
            let built = if let Some(root) = project_root {
                let path = root.join(&terrain.heightmap_path);
                load_rgba8_path(&path)
                    .map(|img| build_terrain_mesh_from_image(&img, terrain.size, seg, seg))
                    .unwrap_or_else(|_| flat_terrain_fallback(terrain.size, seg))
            } else {
                flat_terrain_fallback(terrain.size, seg)
            };
            cache.insert(cache_key, built.clone());
            built
        };
        let c = Color::from_rgba8(terrain.color_rgba);
        let shrink = 1.0 - ring as f32 * 0.12;
        let model = Mat4::translation(Vec3::new(
            terrain.center[0],
            terrain.center[1],
            terrain.center[2],
        ))
        .multiply(Mat4::scale_vec(Vec3::new(shrink, 1.0, shrink)));
        let mesh_path_key = format!("terrain:{}:r{ring}", terrain.heightmap_path);
        let mesh_key = mesh_cache_key(&mesh, Some(mesh_path_key.as_str()));
        out.push(Forward3DDraw {
            model,
            base_color: [c.r, c.g, c.b, c.a * (1.0 - ring as f32 * 0.08)],
            metallic: terrain.metallic,
            roughness: terrain.roughness,
            mesh,
            mesh_key,
            albedo_image: None,
            normal_image: None,
            cast_shadow: ring == 0,
        });
    }
    out
}

fn terrain_draw(
    terrain: &Lynx3dTerrain,
    project_root: Option<&Path>,
    camera_pos: Vec3,
    cache: &mut HashMap<String, Mesh3d>,
) -> Forward3DDraw {
    let dist = terrain_camera_distance(camera_pos, terrain.center);
    let lod = select_terrain_lod(dist, terrain.lod_split_distance, terrain.max_lod);
    let seg = lod_segment_count(terrain.segments, lod);
    let cache_key = format!("{}:lod{lod}:s{seg}", terrain.heightmap_path);
    let mesh = if let Some(m) = cache.get(&cache_key) {
        m.clone()
    } else {
        let built = if let Some(root) = project_root {
            let path = root.join(&terrain.heightmap_path);
            load_rgba8_path(&path)
                .map(|img| build_terrain_mesh_from_image(&img, terrain.size, seg, seg))
                .unwrap_or_else(|_| flat_terrain_fallback(terrain.size, seg))
        } else {
            flat_terrain_fallback(terrain.size, seg)
        };
        cache.insert(cache_key, built.clone());
        built
    };
    let c = Color::from_rgba8(terrain.color_rgba);
    let model = Mat4::translation(Vec3::new(
        terrain.center[0],
        terrain.center[1],
        terrain.center[2],
    ));
    let mesh_path_key = format!("terrain:{}", terrain.heightmap_path);
    let mesh_key = mesh_cache_key(&mesh, Some(mesh_path_key.as_str()));
    Forward3DDraw {
        model,
        base_color: [c.r, c.g, c.b, c.a],
        metallic: terrain.metallic,
        roughness: terrain.roughness,
        mesh,
        mesh_key,
        albedo_image: None,
        normal_image: None,
        cast_shadow: true,
    }
}

fn load_albedo_image(rel: &str, project_root: Option<&Path>) -> Option<Rgba8Image> {
    let root = project_root?;
    load_rgba8_path(&root.join(rel)).ok()
}

fn load_normal_image(rel: &str, project_root: Option<&Path>) -> Option<Rgba8Image> {
    load_albedo_image(rel, project_root)
}

fn object_draw(
    obj: &Lynx3dObject,
    project_root: Option<&Path>,
    cache: &mut HashMap<String, CachedGlb>,
) -> Forward3DDraw {
    let c = Color::from_rgba8(obj.color_rgba);
    let he = obj.half_extents;
    let model = Mat4::model_trs(obj.position, obj.rotation_euler_deg, obj.scale).multiply(
        Mat4::scale_vec(Vec3::new(he[0] * 2.0, he[1] * 2.0, he[2] * 2.0)),
    );
    let mesh_path = obj.mesh_path.as_deref();
    let mesh = resolve_mesh(
        mesh_path,
        project_root,
        obj.animation_clip.as_deref(),
        obj.animation_time_sec,
        cache,
    );
    let mesh_key = mesh_cache_key(&mesh, mesh_path);
    let albedo_image = obj
        .albedo_texture
        .as_deref()
        .and_then(|rel| load_albedo_image(rel, project_root));
    let normal_image = obj
        .normal_texture
        .as_deref()
        .and_then(|rel| load_normal_image(rel, project_root));
    Forward3DDraw {
        model,
        base_color: [c.r, c.g, c.b, c.a],
        metallic: obj.metallic,
        roughness: obj.roughness,
        mesh,
        mesh_key,
        albedo_image,
        normal_image,
        cast_shadow: true,
    }
}

fn room_draws(room: &Lynx3dRoom) -> Vec<Forward3DDraw> {
    let cx = room.center[0];
    let cy = room.center[1];
    let cz = room.center[2];
    let hw = room.width * 0.5;
    let hh = room.height * 0.5;
    let hd = room.depth * 0.5;
    let floor_color = [0.18, 0.2, 0.26, 1.0];
    let wall_color = [0.22, 0.24, 0.32, 1.0];
    let mk = |model: Mat4, color: [f32; 4], cast_shadow: bool| {
        let mesh = Mesh3d::unit_cube();
        let mesh_key = mesh_cache_key(&mesh, None);
        Forward3DDraw {
            model,
            base_color: color,
            metallic: 0.0,
            roughness: 0.85,
            mesh,
            mesh_key,
            albedo_image: None,
            normal_image: None,
            cast_shadow,
        }
    };
    vec![
        mk(
            Mat4::translation(Vec3::new(cx, cy - hh, cz))
                .multiply(Mat4::scale_vec(Vec3::new(hw * 2.0, 0.05, hd * 2.0))),
            floor_color,
            false,
        ),
        mk(
            Mat4::translation(Vec3::new(cx, cy, cz - hd))
                .multiply(Mat4::scale_vec(Vec3::new(hw * 2.0, hh * 2.0, 0.05))),
            wall_color,
            false,
        ),
        mk(
            Mat4::translation(Vec3::new(cx - hw, cy, cz))
                .multiply(Mat4::scale_vec(Vec3::new(0.05, hh * 2.0, hd * 2.0))),
            wall_color,
            false,
        ),
        mk(
            Mat4::translation(Vec3::new(cx + hw, cy, cz))
                .multiply(Mat4::scale_vec(Vec3::new(0.05, hh * 2.0, hd * 2.0))),
            wall_color,
            false,
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scene3d::parse_extension;

    #[test]
    fn albedo_texture_loads_for_gpu() {
        let dir = std::env::temp_dir().join(format!("lynx_m12a_{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dir);
        let tex_path = dir.join("albedo.png");
        let img = image::RgbaImage::from_pixel(2, 2, image::Rgba([200, 40, 40, 255]));
        img.save(&tex_path).expect("save png");

        let json = r##"{
              "active": true,
              "world": { "culling": { "frustum": false, "hiZ": false } },
              "objects": [{
                "id": "tinted",
                "color": "#FFFFFF",
                "material": {
                  "albedoTexture": "albedo.png",
                  "metallic": 0.2,
                  "roughness": 0.5
                }
              }]
            }"##;
        let v: serde_json::Value = serde_json::from_str(&json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let frame = Forward3DFrame::from_lynx3d_scene_with_assets(&scene, 640, 480, 0.0, 0.3, Some(dir.as_path()));
        let draw = frame.draws.iter().find(|d| d.metallic == 0.2).expect("object draw");
        assert!(draw.albedo_image.is_some());
        assert!((draw.base_color[0] - 1.0).abs() < 0.01);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn shadow_settings_defaults() {
        let s = ShadowSettings::default();
        assert!(s.enable_cascade);
        assert!((s.texel_size - 1.0 / 2048.0).abs() < 1e-6);
    }

    #[test]
    fn shadow_cascades_differ_when_enabled() {
        let json = include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/testdata/lynx3d_room_snippet.json"
        ));
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let (c0, c1) = compute_shadow_cascades(
            &scene,
            Vec3::new(0.35, -0.85, 0.4).normalized(),
            true,
        );
        assert_ne!(c0.m, c1.m);
    }

    #[test]
    fn terrain_adds_draw_with_heightmap() {
        let dir = std::env::temp_dir().join(format!("lynx_m13b_{}", std::process::id()));
        let _ = std::fs::create_dir_all(&dir);
        let hm_path = dir.join("hm.png");
        let img = image::RgbaImage::from_pixel(4, 4, image::Rgba([80, 120, 60, 255]));
        img.save(&hm_path).expect("save hm");

        let json = r##"{
          "active": true,
          "terrain": {
            "heightmap": "hm.png",
            "size": [16, 2, 16],
            "center": [0, 0, 0],
            "segments": 8,
            "maxLod": 1,
            "lodSplitDistance": 20
          },
          "objects": []
        }"##;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        assert!(scene.terrain.is_some());
        let frame = Forward3DFrame::from_lynx3d_scene_with_assets(
            &scene, 640, 480, 0.0, 0.3, Some(dir.as_path()),
        );
        assert!(frame.draw_count() >= 1);
        let terrain_draws = frame
            .draws
            .iter()
            .filter(|d| d.mesh.vertex_count() > 8)
            .count();
        assert!(terrain_draws >= 1);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn frame_from_snippet() {
        let json = include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/testdata/lynx3d_room_snippet.json"
        ));
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let frame = Forward3DFrame::from_lynx3d_scene(&scene, 800, 600, 0.5, 0.3);
        assert!(frame.draw_count() >= 5);
        assert!(frame.shadow_cast_count() >= 1);
    }

    #[test]
    fn frustum_culls_offscreen_object() {
        let json = r##"{
          "active": true,
          "room": { "width": 8, "height": 4, "depth": 8, "center": [0, 2, 0] },
          "objects": [
            { "id": "near", "position": [0, 2, 0], "halfExtents": [0.5, 0.5, 0.5] },
            { "id": "far", "position": [0, 2, 40], "halfExtents": [0.5, 0.5, 0.5] }
          ]
        }"##;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let frame = Forward3DFrame::from_lynx3d_scene(&scene, 640, 480, 0.0, 0.35);
        assert_eq!(frame.cull_stats.frustum_culled, 1);
        assert!(frame.draw_count() >= 4);
    }

    #[test]
    fn cull_stats_default_zero_for_visible_room() {
        let json = include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/testdata/lynx3d_room_snippet.json"
        ));
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let frame = Forward3DFrame::from_lynx3d_scene(&scene, 800, 600, 0.5, 0.3);
        assert_eq!(frame.cull_stats.frustum_culled, 0);
        assert_eq!(frame.cull_stats.hiz_culled, 0);
    }
}
