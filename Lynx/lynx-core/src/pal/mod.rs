//! Platform Abstraction Layer (PAL).

#[cfg(target_arch = "wasm32")]
pub mod wasm;

#[cfg(all(windows, feature = "pal_win_d3d12"))]
mod win_d3d12_batch;

#[cfg(all(windows, feature = "pal_win_d3d12"))]
mod win_d3d12_forward3d;

#[cfg(all(windows, feature = "pal_win_d3d12"))]
pub mod win_d3d12_viewport;

#[cfg(all(windows, feature = "pal_win_d3d12"))]
pub mod win_d3d12;

#[cfg(all(windows, feature = "pal_win_d3d12"))]
pub use win_d3d12::{
    run_m1_window_demo, run_m2_window_demo, run_m3_window_demo, M1DemoOptions, M1DemoResult,
    M2DemoOptions, M2DemoResult, M3DemoOptions, M3DemoResult,
};

#[cfg(target_arch = "wasm32")]
pub use wasm::{init_webgpu_stub, WasmSurface};
