//! Lynx Core — proprietary game engine (PAL + RHI; hot path — own code).
//!
//! Phase IV (E24–E27): Core 1.0, WASM PAL, unified render/physics/audio FFI.

pub mod math;
pub mod ffi;
pub mod mem;
pub mod platform;
pub mod render;
pub mod physics;
pub mod audio;
pub mod script;
pub mod asset;
pub mod scene;
pub mod scene3d;

#[cfg(any(feature = "pal_win_d3d12", target_arch = "wasm32"))]
pub mod pal;

#[cfg(target_arch = "wasm32")]
pub mod wasm_api;

pub const CORE_VERSION: &str = "1.0.0";
pub const CORE_API_VERSION: u32 = 5;
