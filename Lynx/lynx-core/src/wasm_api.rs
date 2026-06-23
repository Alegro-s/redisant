//! E25a — WASM exports for browser Lynx Core (tick + PAL stub).

use std::sync::atomic::{AtomicU64, Ordering};

use crate::pal::wasm::init_webgpu_stub;
use crate::{CORE_API_VERSION, CORE_VERSION};

static TICK_COUNT: AtomicU64 = AtomicU64::new(0);

#[unsafe(no_mangle)]
pub extern "C" fn lynx_wasm_core_api_version() -> u32 {
    CORE_API_VERSION
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_wasm_core_version_ptr() -> *const u8 {
    CORE_VERSION.as_ptr()
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_wasm_core_version_len() -> u32 {
    CORE_VERSION.len() as u32
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_wasm_init(width: u32, height: u32) -> u8 {
    match init_webgpu_stub(width, height) {
        Ok(_) => 1,
        Err(_) => 0,
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_wasm_tick(dt: f32) -> u64 {
    let _ = dt.max(0.0);
    TICK_COUNT.fetch_add(1, Ordering::Relaxed) + 1
}

#[unsafe(no_mangle)]
pub extern "C" fn lynx_wasm_tick_count() -> u64 {
    TICK_COUNT.load(Ordering::Relaxed)
}
