//! Контракт `extensions.lynx.3d` (тот же JSON, что Flutter `lynx_3d_codec.dart`).

#[cfg(feature = "serde")]
use serde::Deserialize;

/// M14b: frustum + CPU Hi-Z (см. `render::cull3d`).
#[derive(Clone, Copy, Debug)]
pub struct Lynx3dCulling {
    pub frustum: bool,
    pub hi_z: bool,
    pub hi_z_size: u32,
}

impl Default for Lynx3dCulling {
    fn default() -> Self {
        Self {
            frustum: true,
            hi_z: true,
            hi_z_size: 64,
        }
    }
}

pub struct Lynx3dScene {
    pub active: bool,
    pub gravity: [f32; 3],
    pub ambient_color: [f32; 3],
    pub render: Lynx3dRenderSettings,
    pub camera: Lynx3dCamera,
    pub culling: Lynx3dCulling,
    pub room: Option<Lynx3dRoom>,
    /// Heightmap terrain (M13b); рисуется под room/objects в Forward3D.
    pub terrain: Option<Lynx3dTerrain>,
    pub objects: Vec<Lynx3dObject>,
    /// M14c: hinge constraints between dynamic bodies.
    pub physics_joints: Vec<Lynx3dHingeJoint>,
}

/// Level 2: IBL stub + post (tone map / bloom strength).
#[derive(Clone, Copy, Debug)]
pub struct Lynx3dRenderSettings {
    pub ibl_strength: f32,
    pub post_enabled: bool,
    pub exposure: f32,
    pub bloom: f32,
}

impl Default for Lynx3dRenderSettings {
    fn default() -> Self {
        Self {
            ibl_strength: 0.35,
            post_enabled: true,
            exposure: 1.0,
            bloom: 0.12,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Lynx3dHingeJoint {
    pub body_a: String,
    pub body_b: String,
    pub anchor: [f32; 3],
    pub axis: [f32; 3],
    pub min_angle_deg: f32,
    pub max_angle_deg: f32,
}

#[derive(Clone, Debug)]
pub struct Lynx3dTerrain {
    pub heightmap_path: String,
    /// World [width, max_height, depth].
    pub size: [f32; 3],
    pub center: [f32; 3],
    pub segments: u32,
    pub max_lod: u32,
    pub lod_split_distance: f32,
    /// Level 2: nested clipmap rings (0 = single mesh LOD only).
    pub clipmap_levels: u32,
    pub color_rgba: u32,
    pub metallic: f32,
    pub roughness: f32,
}

#[derive(Clone, Debug)]
pub struct Lynx3dCamera {
    pub fov_y_deg: f32,
    pub near: f32,
    pub far: f32,
    pub orbit_distance: f32,
}

impl Default for Lynx3dCamera {
    fn default() -> Self {
        Self {
            fov_y_deg: 60.0,
            near: 0.1,
            far: 500.0,
            orbit_distance: 12.0,
        }
    }
}

#[derive(Clone, Debug)]
pub struct Lynx3dRoom {
    pub width: f32,
    pub height: f32,
    pub depth: f32,
    pub center: [f32; 3],
}

#[derive(Clone, Debug)]
pub struct Lynx3dObject {
    pub id: String,
    pub mesh_path: Option<String>,
    pub position: [f32; 3],
    pub rotation_euler_deg: [f32; 3],
    pub scale: [f32; 3],
    pub half_extents: [f32; 3],
    pub color_rgba: u32,
    pub metallic: f32,
    pub roughness: f32,
    /// Относительный путь albedo PNG (M12a); GPU sampling — 12b.
    pub albedo_texture: Option<String>,
    /// Level 2: tangent-space normal map PNG.
    pub normal_texture: Option<String>,
    /// MR текстура (контракт); пока только scalar metallic/roughness.
    pub metallic_roughness_texture: Option<String>,
    /// Имя GLTF animation clip (M13a); пусто = bind pose.
    pub animation_clip: Option<String>,
    /// Время клипа в секундах (M13a).
    pub animation_time_sec: f32,
    /// M14a: static collider (не двигается solver).
    pub is_static: bool,
    pub restitution: f32,
    pub friction: f32,
}

impl Default for Lynx3dScene {
    fn default() -> Self {
        Self {
            active: true,
            gravity: [0.0, -9.81, 0.0],
            ambient_color: [0.25, 0.25, 0.31],
            render: Lynx3dRenderSettings::default(),
            camera: Lynx3dCamera::default(),
            culling: Lynx3dCulling::default(),
            room: Some(Lynx3dRoom {
                width: 8.0,
                height: 4.0,
                depth: 8.0,
                center: [0.0, 2.0, 0.0],
            }),
            terrain: None,
            objects: Vec::new(),
            physics_joints: Vec::new(),
        }
    }
}

/// Парсинг блока `extensions["lynx.3d"]`.
#[cfg(feature = "serde")]
pub fn parse_extension(value: &serde_json::Value) -> Result<Lynx3dScene, String> {
    let raw: Lynx3dExtensionRaw = serde_json::from_value(value.clone())
        .map_err(|e| format!("lynx.3d json: {e}"))?;
    raw.into_scene()
}

/// Из полного JSON сцены v3 (`formatVersion`, `extensions`, …).
#[cfg(feature = "serde")]
pub fn parse_extension_from_scene_json(text: &str) -> Result<Lynx3dScene, String> {
    let root: serde_json::Value =
        serde_json::from_str(text).map_err(|e| format!("scene json: {e}"))?;
    let ext = root
        .get("extensions")
        .and_then(|e| e.get("lynx.3d"))
        .ok_or("extensions.lynx.3d not found")?;
    parse_extension(ext)
}

pub const LYNX_3D_PLUGIN_ID: &str = "lynx.3d";

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dExtensionRaw {
    #[serde(default = "default_true")]
    active: bool,
    #[serde(default)]
    world: Option<Lynx3dWorldRaw>,
    #[serde(default)]
    camera: Option<Lynx3dCameraRaw>,
    #[serde(default)]
    room: Option<Lynx3dRoomRaw>,
    #[serde(default)]
    terrain: Option<Lynx3dTerrainRaw>,
    #[serde(default)]
    objects: Vec<Lynx3dObjectRaw>,
    #[serde(default, alias = "physicsJoints")]
    physics_joints: Vec<Lynx3dHingeJointRaw>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dTerrainRaw {
    heightmap: String,
    #[serde(default = "default_terrain_size")]
    size: Vec<f32>,
    #[serde(default = "default_terrain_center")]
    center: Vec<f32>,
    #[serde(default = "default_terrain_segments")]
    segments: u32,
    #[serde(default = "default_terrain_max_lod", alias = "maxLod")]
    max_lod: u32,
    #[serde(default, alias = "lodSplitDistance")]
    lod_split_distance: f32,
    #[serde(default, alias = "clipmapLevels")]
    clipmap_levels: u32,
    color: Option<serde_json::Value>,
    #[serde(default)]
    color_argb: Option<u32>,
    #[serde(default)]
    material: Option<Lynx3dMaterialRaw>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dWorldRaw {
    #[serde(rename = "ambientColor", default = "default_ambient")]
    ambient_color: String,
    #[serde(default = "default_gravity")]
    gravity: Vec<f32>,
    #[serde(default)]
    culling: Option<Lynx3dCullingRaw>,
    #[serde(default)]
    render: Option<Lynx3dRenderRaw>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dRenderRaw {
    #[serde(default, alias = "iblStrength")]
    ibl_strength: f32,
    #[serde(default, alias = "postEnabled")]
    post_enabled: bool,
    #[serde(default)]
    exposure: f32,
    #[serde(default)]
    bloom: f32,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dHingeJointRaw {
    #[serde(default)]
    r#type: String,
    #[serde(default, alias = "bodyA")]
    body_a: String,
    #[serde(default, alias = "bodyB")]
    body_b: String,
    #[serde(default)]
    anchor: Vec<f32>,
    #[serde(default)]
    axis: Vec<f32>,
    #[serde(default, alias = "minAngleDeg")]
    min_angle_deg: f32,
    #[serde(default, alias = "maxAngleDeg")]
    max_angle_deg: f32,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dCullingRaw {
    #[serde(default = "default_true")]
    frustum: bool,
    #[serde(default = "default_true", alias = "hiZ")]
    hi_z: bool,
    #[serde(default = "default_hiz_size", alias = "hiZSize")]
    hi_z_size: u32,
}

fn default_hiz_size() -> u32 {
    64
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dCameraRaw {
    #[serde(rename = "fovY", default = "default_fov")]
    fov_y: f32,
    #[serde(default = "default_near")]
    near: f32,
    #[serde(default = "default_far")]
    far: f32,
    #[serde(default = "default_orbit")]
    orbit_distance: f32,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dRoomRaw {
    #[serde(default = "default_room_w")]
    width: f32,
    #[serde(default = "default_room_h")]
    height: f32,
    #[serde(default = "default_room_d")]
    depth: f32,
    #[serde(default = "default_room_center")]
    center: Vec<f32>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dObjectRaw {
    id: Option<String>,
    #[serde(rename = "sceneObjectId")]
    scene_object_id: Option<String>,
    mesh: Option<String>,
    #[serde(default)]
    transform: Option<Lynx3dTransformRaw>,
    #[serde(default)]
    position: Option<Vec<f32>>,
    #[serde(default, alias = "rotationEuler")]
    rotation_euler: Option<Vec<f32>>,
    #[serde(default)]
    scale: Option<Vec<f32>>,
    #[serde(default, alias = "halfExtents")]
    half_extents: Option<Vec<f32>>,
    color: Option<serde_json::Value>,
    #[serde(default)]
    color_argb: Option<u32>,
    #[serde(default)]
    material: Option<Lynx3dMaterialRaw>,
    #[serde(default, alias = "animationClip")]
    animation_clip: Option<String>,
    #[serde(default, alias = "animationTime")]
    animation_time: Option<f32>,
    #[serde(default)]
    physics: Option<Lynx3dPhysicsRaw>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dPhysicsRaw {
    #[serde(default, alias = "bodyType")]
    body_type: Option<String>,
    #[serde(default)]
    is_static: Option<bool>,
    #[serde(default)]
    restitution: Option<f32>,
    #[serde(default)]
    friction: Option<f32>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dTransformRaw {
    #[serde(default)]
    position: Option<Vec<f32>>,
    #[serde(default, alias = "rotationEuler")]
    rotation_euler: Option<Vec<f32>>,
    #[serde(default)]
    scale: Option<Vec<f32>>,
}

#[cfg(feature = "serde")]
#[derive(Debug, Deserialize)]
struct Lynx3dMaterialRaw {
    #[serde(default)]
    metallic: Option<f32>,
    #[serde(default)]
    roughness: Option<f32>,
    #[serde(default, alias = "albedoTexture")]
    albedo_texture: Option<String>,
    #[serde(default, alias = "normalTexture")]
    normal_texture: Option<String>,
    #[serde(default, alias = "metallicRoughnessTexture")]
    metallic_roughness_texture: Option<String>,
}

#[cfg(feature = "serde")]
impl Lynx3dExtensionRaw {
    fn into_scene(self) -> Result<Lynx3dScene, String> {
        if !self.active {
            return Ok(Lynx3dScene {
                active: false,
                ..Lynx3dScene::default()
            });
        }
        let world = self.world.unwrap_or(Lynx3dWorldRaw {
            ambient_color: default_ambient(),
            gravity: default_gravity(),
            culling: None,
            render: None,
        });
        let culling = world
            .culling
            .map(|c| Lynx3dCulling {
                frustum: c.frustum,
                hi_z: c.hi_z,
                hi_z_size: c.hi_z_size.clamp(16, 256),
            })
            .unwrap_or_default();
        let cam = self.camera.unwrap_or(Lynx3dCameraRaw {
            fov_y: default_fov(),
            near: default_near(),
            far: default_far(),
            orbit_distance: default_orbit(),
        });
        let mut objects = Vec::new();
        for o in self.objects {
            objects.push(o.into_object()?);
        }
        let render = world.render.as_ref().map(|r| Lynx3dRenderSettings {
            ibl_strength: if r.ibl_strength > 0.0 { r.ibl_strength } else { 0.35 },
            post_enabled: r.post_enabled,
            exposure: if r.exposure > 0.0 { r.exposure } else { 1.0 },
            bloom: r.bloom.max(0.0),
        }).unwrap_or_default();
        let physics_joints = self
            .physics_joints
            .into_iter()
            .filter(|j| j.r#type == "hinge" || j.r#type.is_empty())
            .map(|j| Lynx3dHingeJoint {
                body_a: j.body_a,
                body_b: j.body_b,
                anchor: vec3_or(Some(j.anchor), [0.0, 1.0, 0.0]),
                axis: {
                    let a = vec3_or(Some(j.axis), [0.0, 1.0, 0.0]);
                    let len = (a[0] * a[0] + a[1] * a[1] + a[2] * a[2]).sqrt().max(1e-6);
                    [a[0] / len, a[1] / len, a[2] / len]
                },
                min_angle_deg: j.min_angle_deg,
                max_angle_deg: j.max_angle_deg,
            })
            .collect();
        Ok(Lynx3dScene {
            active: true,
            gravity: vec3_or(Some(world.gravity), [0.0, -9.81, 0.0]),
            ambient_color: parse_hex_color(&world.ambient_color)
                .unwrap_or([0.25, 0.25, 0.31]),
            render,
            camera: Lynx3dCamera {
                fov_y_deg: cam.fov_y,
                near: cam.near,
                far: cam.far,
                orbit_distance: cam.orbit_distance,
            },
            culling,
            room: self.room.map(|r| Lynx3dRoom {
                width: r.width,
                height: r.height,
                depth: r.depth,
                center: vec3_or(Some(r.center), [0.0, 2.0, 0.0]),
            }),
            terrain: self.terrain.map(|t| t.into_terrain()).transpose()?,
            objects,
            physics_joints,
        })
    }
}

#[cfg(feature = "serde")]
impl Lynx3dTerrainRaw {
    fn into_terrain(self) -> Result<Lynx3dTerrain, String> {
        let size = vec3_or(Some(self.size), [32.0, 4.0, 32.0]);
        let center = vec3_or(Some(self.center), [0.0, 0.0, 0.0]);
        let color_rgba = self
            .color_argb
            .or_else(|| self.color.as_ref().and_then(parse_color_value))
            .unwrap_or(0xFF3D5C3D);
        let mat = self.material.as_ref();
        let (metallic, roughness) = mat
            .map(|m| (m.metallic.unwrap_or(0.0), m.roughness.unwrap_or(0.85)))
            .unwrap_or((0.0, 0.85));
        Ok(Lynx3dTerrain {
            heightmap_path: self.heightmap,
            size,
            center,
            segments: self.segments.max(2),
            max_lod: self.max_lod,
            lod_split_distance: if self.lod_split_distance > 0.0 {
                self.lod_split_distance
            } else {
                12.0
            },
            clipmap_levels: self.clipmap_levels.min(4),
            color_rgba,
            metallic,
            roughness,
        })
    }
}

#[cfg(feature = "serde")]
impl Lynx3dObjectRaw {
    fn into_object(self) -> Result<Lynx3dObject, String> {
        let id = self
            .id
            .or(self.scene_object_id)
            .unwrap_or_else(|| "obj".into());
        let t = self.transform;
        let position = vec3_or(
            t.as_ref()
                .and_then(|x| x.position.clone())
                .or(self.position),
            [0.0, 1.0, 0.0],
        );
        let rotation_euler_deg = vec3_or(
            t.as_ref()
                .and_then(|x| x.rotation_euler.clone())
                .or(self.rotation_euler),
            [0.0, 0.0, 0.0],
        );
        let scale = vec3_or(
            t.as_ref().and_then(|x| x.scale.clone()).or(self.scale),
            [1.0, 1.0, 1.0],
        );
        let half_extents = vec3_or(self.half_extents, [0.5, 0.5, 0.5]);
        let color_rgba = self
            .color_argb
            .or_else(|| self.color.as_ref().and_then(parse_color_value))
            .unwrap_or(0xFF8D6E63);
        let mat = self.material.as_ref();
        let (metallic, roughness) = mat
            .map(|m| (m.metallic.unwrap_or(0.0), m.roughness.unwrap_or(0.65)))
            .unwrap_or((0.0, 0.65));
        let (is_static, restitution, friction) = parse_physics(self.physics.as_ref());
        Ok(Lynx3dObject {
            id,
            mesh_path: self.mesh,
            position,
            rotation_euler_deg,
            scale,
            half_extents,
            color_rgba,
            metallic,
            roughness,
            albedo_texture: mat.and_then(|m| m.albedo_texture.clone()),
            normal_texture: mat.and_then(|m| m.normal_texture.clone()),
            metallic_roughness_texture: mat
                .and_then(|m| m.metallic_roughness_texture.clone()),
            animation_clip: self.animation_clip,
            animation_time_sec: self.animation_time.unwrap_or(0.0),
            is_static,
            restitution,
            friction,
        })
    }
}

#[cfg(feature = "serde")]
fn parse_physics(p: Option<&Lynx3dPhysicsRaw>) -> (bool, f32, f32) {
    let Some(p) = p else {
        return (false, 0.15, 0.55);
    };
    let is_static = p.is_static.unwrap_or_else(|| {
        matches!(
            p.body_type.as_deref(),
            Some("static" | "Static" | "STATIC")
        )
    });
    let restitution = p.restitution.unwrap_or(0.15);
    let friction = p.friction.unwrap_or(0.55);
    (is_static, restitution, friction)
}

fn vec3_or(v: Option<Vec<f32>>, def: [f32; 3]) -> [f32; 3] {
    match v {
        Some(a) if a.len() >= 3 => [a[0], a[1], a[2]],
        _ => def,
    }
}

fn parse_hex_color(s: &str) -> Option<[f32; 3]> {
    let hex = s.strip_prefix('#')?;
    let n = u32::from_str_radix(hex.get(..6.min(hex.len()))?, 16).ok()?;
    Some([
        ((n >> 16) & 0xFF) as f32 / 255.0,
        ((n >> 8) & 0xFF) as f32 / 255.0,
        (n & 0xFF) as f32 / 255.0,
    ])
}

#[cfg(feature = "serde")]
fn parse_color_value(v: &serde_json::Value) -> Option<u32> {
    match v {
        serde_json::Value::Number(n) => n.as_u64().map(|x| x as u32),
        serde_json::Value::String(s) => {
            let rgb = parse_hex_color(s)?;
            Some(0xFF000000 | ((rgb[0] * 255.0) as u32) << 16 | ((rgb[1] * 255.0) as u32) << 8 | (rgb[2] * 255.0) as u32)
        }
        _ => None,
    }
}

#[cfg(feature = "serde")]
fn default_true() -> bool {
    true
}
#[cfg(feature = "serde")]
fn default_ambient() -> String {
    "#404050".into()
}
#[cfg(feature = "serde")]
fn default_gravity() -> Vec<f32> {
    vec![0.0, -9.81, 0.0]
}
#[cfg(feature = "serde")]
fn default_fov() -> f32 {
    60.0
}
#[cfg(feature = "serde")]
fn default_near() -> f32 {
    0.1
}
#[cfg(feature = "serde")]
fn default_far() -> f32 {
    500.0
}
#[cfg(feature = "serde")]
fn default_orbit() -> f32 {
    12.0
}
#[cfg(feature = "serde")]
fn default_room_w() -> f32 {
    8.0
}
#[cfg(feature = "serde")]
fn default_room_h() -> f32 {
    4.0
}
#[cfg(feature = "serde")]
fn default_room_d() -> f32 {
    8.0
}
#[cfg(feature = "serde")]
fn default_room_center() -> Vec<f32> {
    vec![0.0, 2.0, 0.0]
}
#[cfg(feature = "serde")]
fn default_terrain_size() -> Vec<f32> {
    vec![32.0, 4.0, 32.0]
}
#[cfg(feature = "serde")]
fn default_terrain_center() -> Vec<f32> {
    vec![0.0, 0.0, 0.0]
}
#[cfg(feature = "serde")]
fn default_terrain_segments() -> u32 {
    32
}
#[cfg(feature = "serde")]
fn default_terrain_max_lod() -> u32 {
    2
}

#[cfg(all(test, feature = "serde"))]
mod tests {
    use super::*;

    #[test]
    fn parse_material_albedo_texture() {
        let json = r#"{
          "active": true,
          "objects": [{
            "id": "x",
            "material": {
              "albedoTexture": "assets/tex.png",
              "metallicRoughnessTexture": "assets/mr.png",
              "metallic": 0.1,
              "roughness": 0.9
            }
          }]
        }"#;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let o = &scene.objects[0];
        assert_eq!(o.albedo_texture.as_deref(), Some("assets/tex.png"));
        assert_eq!(
            o.metallic_roughness_texture.as_deref(),
            Some("assets/mr.png")
        );
        assert!((o.metallic - 0.1).abs() < 0.001);
    }

    #[test]
    fn parse_demo_room_json() {
        let json = include_str!(concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/testdata/lynx3d_room_snippet.json"
        ));
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        assert!(scene.active);
        assert_eq!(scene.objects.len(), 1);
        assert_eq!(scene.objects[0].id, "crate_3d");
    }

    #[test]
    fn parse_physics_block() {
        let json = r#"{
          "active": true,
          "objects": [{
            "id": "wall",
            "physics": { "bodyType": "static", "restitution": 0.0, "friction": 0.9 }
          }, {
            "id": "crate",
            "physics": { "bodyType": "dynamic" }
          }]
        }"#;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        assert!(scene.objects[0].is_static);
        assert!(!scene.objects[1].is_static);
        assert!((scene.objects[1].restitution - 0.15).abs() < 0.01);
    }

    #[test]
    fn parse_culling_block() {
        let json = r#"{
          "active": true,
          "world": {
            "culling": { "frustum": false, "hiZ": true, "hiZSize": 48 }
          }
        }"#;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        assert!(!scene.culling.frustum);
        assert!(scene.culling.hi_z);
        assert_eq!(scene.culling.hi_z_size, 48);
    }

    #[test]
    fn parse_terrain_block() {
        let json = r#"{
          "active": true,
          "terrain": {
            "heightmap": "assets/terrain/hm.png",
            "size": [64, 8, 64],
            "center": [0, 0, 0],
            "segments": 32,
            "maxLod": 2
          }
        }"#;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let t = scene.terrain.as_ref().expect("terrain");
        assert_eq!(t.heightmap_path, "assets/terrain/hm.png");
        assert!((t.size[0] - 64.0).abs() < 0.01);
        assert_eq!(t.segments, 32);
        assert_eq!(t.max_lod, 2);
    }

    #[test]
    fn parse_animation_clip_fields() {
        let json = r#"{
          "active": true,
          "objects": [{
            "id": "skel",
            "mesh": "assets/char.glb",
            "animationClip": "walk",
            "animationTime": 0.42
          }]
        }"#;
        let v: serde_json::Value = serde_json::from_str(json).unwrap();
        let scene = parse_extension(&v).unwrap();
        let o = &scene.objects[0];
        assert_eq!(o.animation_clip.as_deref(), Some("walk"));
        assert!((o.animation_time_sec - 0.42).abs() < 1e-4);
    }

    #[test]
    fn parse_from_full_scene_wrapper() {
        let wrapped = format!(
            r#"{{
  "formatVersion": 3,
  "extensions": {{
    "lynx.3d": {}
  }}
}}"#,
            include_str!(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/testdata/lynx3d_room_snippet.json"
            ))
        );
        let scene = parse_extension_from_scene_json(&wrapped).unwrap();
        assert!(scene.active);
        assert_eq!(scene.objects.len(), 1);
    }
}
