//! C FFI для Lynx Core (batch2d). Legacy `engine` реэкспортирует те же символы.

use std::ffi::{c_char, c_void, CStr, CString};
use std::path::Path;
use std::ptr;

use crate::physics::Physics3dWorld;
use crate::physics::Physics2dWorld;
use crate::audio::AudioMixer;
use crate::render::batch2d::{Batch2DSprite, SpriteBatch2D};
#[cfg(feature = "serde")]
use crate::render::forward3d::Forward3DFrame;
#[cfg(feature = "serde")]
use crate::scene3d::{parse_extension, parse_extension_from_scene_json, Lynx3dScene};
use crate::scene::SceneRuntime;
use crate::script::{compile, is_lynxscript, run_script, ScriptHost};
use crate::{CORE_API_VERSION, CORE_VERSION};

#[repr(C)]
#[derive(Clone, Copy)]
pub struct LynxBatch2DSpriteC {
    pub center_x: f32,
    pub center_y: f32,
    pub width: f32,
    pub height: f32,
    pub color_rgba: u32,
    pub uv0: f32,
    pub uv1: f32,
    pub uv2: f32,
    pub uv3: f32,
    pub texture_id: u32,
    pub sorting_layer: i32,
    pub order_in_layer: i32,
    pub rot_deg: f32,
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_core_api_version() -> u32 {
    CORE_API_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_core_version_string() -> *mut c_char {
    CString::new(CORE_VERSION).ok().map(|s| s.into_raw()).unwrap_or(ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_create(capacity: u32) -> *mut c_void {
    let cap = if capacity == 0 { 4096 } else { capacity as usize };
    Box::into_raw(Box::new(SpriteBatch2D::new(cap))) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut SpriteBatch2D));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_clear(ptr: *mut c_void) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        (*(ptr as *mut SpriteBatch2D)).clear();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_set_viewport(ptr: *mut c_void, width: f32, height: f32) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        (*(ptr as *mut SpriteBatch2D)).set_viewport(width, height);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_len(ptr: *const c_void) -> u32 {
    if ptr.is_null() {
        return 0;
    }
    unsafe { (*(ptr as *const SpriteBatch2D)).len() as u32 }
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_push(ptr: *mut c_void, sprite: LynxBatch2DSpriteC) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    let s = Batch2DSprite {
        center_x: sprite.center_x,
        center_y: sprite.center_y,
        width: sprite.width,
        height: sprite.height,
        color_rgba: sprite.color_rgba,
        uv: [sprite.uv0, sprite.uv1, sprite.uv2, sprite.uv3],
        texture_id: sprite.texture_id,
        sorting_layer: sprite.sorting_layer,
        order_in_layer: sprite.order_in_layer,
        rot_deg: sprite.rot_deg,
    };
    unsafe {
        if (*(ptr as *mut SpriteBatch2D)).push_sprite(s) {
            1
        } else {
            0
        }
    }
}

/// Парсинг JSON `extensions.lynx.3d`; возвращает число объектов или `u32::MAX` при ошибке.
#[cfg(feature = "serde")]
#[unsafe(no_mangle)]
pub extern "C" fn lynx3d_parse_extension_object_count(json: *const c_char) -> u32 {
    if json.is_null() {
        return u32::MAX;
    }
    unsafe {
        let s = match std::ffi::CStr::from_ptr(json).to_str() {
            Ok(x) => x,
            Err(_) => return u32::MAX,
        };
        let v: serde_json::Value = match serde_json::from_str(s) {
            Ok(v) => v,
            Err(_) => return u32::MAX,
        };
        match parse_extension(&v) {
            Ok(scene) if scene.active => scene.objects.len() as u32,
            Ok(_) => 0,
            Err(_) => u32::MAX,
        }
    }
}

/// Число draw-call'ов forward 3D для JSON `extensions.lynx.3d` или полной сцены v3.
#[cfg(feature = "serde")]
#[unsafe(no_mangle)]
pub extern "C" fn forward3d_frame_draw_count(
    json: *const c_char,
    project_root: *const c_char,
) -> u32 {
    if json.is_null() {
        return u32::MAX;
    }
    unsafe {
        let s = match CStr::from_ptr(json).to_str() {
            Ok(x) => x,
            Err(_) => return u32::MAX,
        };
        let root = if project_root.is_null() {
            None
        } else {
            CStr::from_ptr(project_root).to_str().ok().map(Path::new)
        };
        let scene = if s.contains("\"extensions\"") {
            match parse_extension_from_scene_json(s) {
                Ok(scene) => scene,
                Err(_) => return u32::MAX,
            }
        } else {
            let v: serde_json::Value = match serde_json::from_str(s) {
                Ok(v) => v,
                Err(_) => return u32::MAX,
            };
            match parse_extension(&v) {
                Ok(scene) => scene,
                Err(_) => return u32::MAX,
            }
        };
        if !scene.active {
            return 0;
        }
        Forward3DFrame::from_lynx3d_scene_with_assets(&scene, 800, 600, 0.0, 0.3, root).draw_count()
            as u32
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct LynxScriptEntityState {
    pub x: f32,
    pub y: f32,
    pub dt: f32,
    pub on_ground: u8,
    pub action_jump: u8,
}

#[unsafe(no_mangle)]
pub extern "C" fn lynxscript_is(source: *const c_char) -> u8 {
    if source.is_null() {
        return 0;
    }
    unsafe {
        match CStr::from_ptr(source).to_str() {
            Ok(s) if is_lynxscript(s) => 1,
            _ => 0,
        }
    }
}

/// 0 = not lynxscript, 1 = ok, 2 = compile/run error.
#[unsafe(no_mangle)]
pub extern "C" fn lynxscript_run(source: *const c_char, state: *mut LynxScriptEntityState) -> u8 {
    if source.is_null() || state.is_null() {
        return 2;
    }
    unsafe {
        let code = match CStr::from_ptr(source).to_str() {
            Ok(s) => s,
            Err(_) => return 2,
        };
        if !is_lynxscript(code) {
            return 0;
        }
        let prog = match compile(code) {
            Ok(p) => p,
            Err(_) => return 2,
        };
        let st = &mut *state;
        let mut actions = std::collections::HashMap::new();
        if st.action_jump != 0 {
            actions.insert("jump".to_string(), true);
        }
        let mut host = ScriptHost {
            x: st.x,
            y: st.y,
            vx: 0.0,
            vy: 0.0,
            dt: st.dt,
            on_ground: st.on_ground != 0,
            key_a: false,
            key_d: false,
            key_space: st.action_jump != 0,
            actions,
            velocity_set: false,
            out_vx: 0.0,
            out_vy: 0.0,
        };
        if run_script(&prog, &mut host).is_err() {
            return 2;
        }
        st.x = host.x;
        st.y = host.y;
        1
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_runtime_create() -> *mut c_void {
    Box::into_raw(Box::new(SceneRuntime::new())) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_runtime_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut SceneRuntime));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_runtime_load(ptr: *mut c_void, scene_id: *const c_char) -> u8 {
    if ptr.is_null() || scene_id.is_null() {
        return 0;
    }
    unsafe {
        let id = match CStr::from_ptr(scene_id).to_str() {
            Ok(s) => s,
            Err(_) => return 0,
        };
        (*(ptr as *mut SceneRuntime)).load_scene(id);
        1
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_runtime_push(ptr: *mut c_void, scene_id: *const c_char) -> u8 {
    if ptr.is_null() || scene_id.is_null() {
        return 0;
    }
    unsafe {
        let id = match CStr::from_ptr(scene_id).to_str() {
            Ok(s) => s,
            Err(_) => return 0,
        };
        (*(ptr as *mut SceneRuntime)).push_scene(id);
        1
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_runtime_pop(ptr: *mut c_void) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    unsafe {
        if (*(ptr as *mut SceneRuntime)).pop_scene() {
            1
        } else {
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn scene_runtime_take_pending(ptr: *mut c_void) -> *mut c_char {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        match (*(ptr as *mut SceneRuntime)).take_pending_load() {
            Some(id) => CString::new(id).ok().map(|s| s.into_raw()).unwrap_or(ptr::null_mut()),
            None => ptr::null_mut(),
        }
    }
}

/// 1 если сборка с D3D12 viewport (Windows Player Q3).
#[cfg(all(windows, feature = "pal_win_d3d12"))]
#[unsafe(no_mangle)]
pub extern "C" fn lynx_viewport_available() -> u8 {
    1
}

#[cfg(not(all(windows, feature = "pal_win_d3d12")))]
#[unsafe(no_mangle)]
pub extern "C" fn lynx_viewport_available() -> u8 {
    0
}

#[cfg(all(windows, feature = "pal_win_d3d12"))]
#[unsafe(no_mangle)]
pub extern "C" fn lynx_viewport_create(
    parent_hwnd: isize,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) -> *mut c_void {
    match unsafe {
        crate::pal::win_d3d12_viewport::viewport_create_raw(parent_hwnd, x, y, width, height)
    } {
        Ok(vp) => Box::into_raw(vp) as *mut c_void,
        Err(_) => ptr::null_mut(),
    }
}

#[cfg(all(windows, feature = "pal_win_d3d12"))]
#[unsafe(no_mangle)]
pub extern "C" fn lynx_viewport_destroy(ptr: *mut c_void) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        crate::pal::win_d3d12_viewport::viewport_destroy(ptr as *mut crate::pal::win_d3d12_viewport::CoreViewport);
    }
}

#[cfg(all(windows, feature = "pal_win_d3d12"))]
#[unsafe(no_mangle)]
pub extern "C" fn lynx_viewport_resize(ptr: *mut c_void, width: u32, height: u32) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    unsafe {
        let vp = &mut *(ptr as *mut crate::pal::win_d3d12_viewport::CoreViewport);
        crate::pal::win_d3d12_viewport::viewport_resize(vp, width, height)
            .map(|_| 1)
            .unwrap_or(0)
    }
}

#[cfg(all(windows, feature = "pal_win_d3d12"))]
#[unsafe(no_mangle)]
pub extern "C" fn lynx_viewport_present_lynx3d(
    ptr: *mut c_void,
    json: *const c_char,
    project_root: *const c_char,
    orbit_yaw_rad: f32,
    orbit_pitch_rad: f32,
) -> u8 {
    if ptr.is_null() || json.is_null() {
        return 0;
    }
    unsafe {
        let vp = &mut *(ptr as *mut crate::pal::win_d3d12_viewport::CoreViewport);
        let s = match CStr::from_ptr(json).to_str() {
            Ok(x) => x,
            Err(_) => return 0,
        };
        let root = if project_root.is_null() {
            None
        } else {
            CStr::from_ptr(project_root)
                .to_str()
                .ok()
                .map(Path::new)
        };
        match crate::pal::win_d3d12_viewport::viewport_present_lynx3d_json(
            vp,
            s,
            root,
            orbit_yaw_rad,
            orbit_pitch_rad,
        ) {
            Ok(()) => 1,
            Err(_) => 0,
        }
    }
}

#[cfg(feature = "serde")]
fn parse_lynx3d_scene_from_cstr(json: *const c_char) -> Option<Lynx3dScene> {
    if json.is_null() {
        return None;
    }
    unsafe {
        let s = CStr::from_ptr(json).to_str().ok()?;
        if s.contains("\"extensions\"") {
            parse_extension_from_scene_json(s).ok()
        } else {
            let v: serde_json::Value = serde_json::from_str(s).ok()?;
            parse_extension(&v).ok()
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_create() -> *mut c_void {
    Box::into_raw(Box::new(Physics3dWorld::new())) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut Physics3dWorld));
        }
    }
}

#[cfg(feature = "serde")]
#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_load_lynx3d(ptr: *mut c_void, json: *const c_char) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    let Some(scene) = parse_lynx3d_scene_from_cstr(json) else {
        return 0;
    };
    unsafe {
        *(ptr as *mut Physics3dWorld) = Physics3dWorld::from_lynx3d_scene(&scene);
    }
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_step(ptr: *mut c_void, dt: f32) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    unsafe {
        (*(ptr as *mut Physics3dWorld)).step(dt);
    }
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_body_count(ptr: *const c_void) -> u32 {
    if ptr.is_null() {
        return 0;
    }
    unsafe { (*(ptr as *const Physics3dWorld)).bodies.len() as u32 }
}

#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_body_position(
    ptr: *const c_void,
    index: u32,
    out_xyz: *mut f32,
) -> u8 {
    if ptr.is_null() || out_xyz.is_null() {
        return 0;
    }
    unsafe {
        let world = &*(ptr as *const Physics3dWorld);
        let Some(body) = world.bodies.get(index as usize) else {
            return 0;
        };
        let out = std::slice::from_raw_parts_mut(out_xyz, 3);
        out.copy_from_slice(&body.position);
    }
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn physics3d_world_body_id(
    ptr: *const c_void,
    index: u32,
) -> *mut c_char {
    if ptr.is_null() {
        return ptr::null_mut();
    }
    unsafe {
        let world = &*(ptr as *const Physics3dWorld);
        let Some(body) = world.bodies.get(index as usize) else {
            return ptr::null_mut();
        };
        CString::new(body.id.as_str())
            .ok()
            .map(|s| s.into_raw())
            .unwrap_or(ptr::null_mut())
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn batch2d_build_vertex_count(ptr: *mut c_void) -> u32 {
    if ptr.is_null() {
        return 0;
    }
    unsafe {
        (*(ptr as *mut SpriteBatch2D))
            .build_vertices()
            .len() as u32
    }
}

// --- E27 physics2d unified ---

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_create() -> *mut c_void {
    Box::into_raw(Box::new(Physics2dWorld::new())) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut Physics2dWorld));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_set_gravity(ptr: *mut c_void, gravity_y: f32) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        (*(ptr as *mut Physics2dWorld)).gravity_y = gravity_y;
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_add_dynamic(
    ptr: *mut c_void,
    id: u32,
    x: f32,
    y: f32,
    half_w: f32,
    half_h: f32,
) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    unsafe {
        (*(ptr as *mut Physics2dWorld)).add_dynamic(id, x, y, half_w, half_h);
    }
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_step(ptr: *mut c_void, dt: f32) -> u8 {
    if ptr.is_null() {
        return 0;
    }
    unsafe {
        (*(ptr as *mut Physics2dWorld)).step(dt);
    }
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_body_count(ptr: *const c_void) -> u32 {
    if ptr.is_null() {
        return 0;
    }
    unsafe { (*(ptr as *const Physics2dWorld)).bodies.len() as u32 }
}

#[unsafe(no_mangle)]
pub extern "C" fn physics2d_world_body_position(ptr: *const c_void, index: u32, out_xy: *mut f32) -> u8 {
    if ptr.is_null() || out_xy.is_null() {
        return 0;
    }
    unsafe {
        let world = &*(ptr as *const Physics2dWorld);
        let Some(pos) = world.body_position(index as usize) else {
            return 0;
        };
        let out = std::slice::from_raw_parts_mut(out_xy, 2);
        out.copy_from_slice(&pos);
    }
    1
}

// --- E27 audio unified ---

#[unsafe(no_mangle)]
pub extern "C" fn audio_mixer_create() -> *mut c_void {
    Box::into_raw(Box::new(AudioMixer::new())) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn audio_mixer_destroy(ptr: *mut c_void) {
    if !ptr.is_null() {
        unsafe {
            drop(Box::from_raw(ptr as *mut AudioMixer));
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn audio_mixer_set_master(ptr: *mut c_void, volume: f32) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        (*(ptr as *mut AudioMixer)).set_master(volume);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn audio_mixer_queue_play(
    ptr: *mut c_void,
    path: *const c_char,
    bus: *const c_char,
    volume: f32,
) -> u8 {
    if ptr.is_null() || path.is_null() {
        return 0;
    }
    unsafe {
        let path_s = match CStr::from_ptr(path).to_str() {
            Ok(s) => s,
            Err(_) => return 0,
        };
        let bus_s = if bus.is_null() {
            "default"
        } else {
            match CStr::from_ptr(bus).to_str() {
                Ok(s) => s,
                Err(_) => "default",
            }
        };
        (*(ptr as *mut AudioMixer)).queue_play(path_s, bus_s, volume);
    }
    1
}

#[unsafe(no_mangle)]
pub extern "C" fn audio_mixer_pending_count(ptr: *const c_void) -> u32 {
    if ptr.is_null() {
        return 0;
    }
    unsafe { (*(ptr as *const AudioMixer)).pending_len() as u32 }
}
