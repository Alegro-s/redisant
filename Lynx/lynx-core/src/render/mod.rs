//! RHI + 2D batch (M2). Target: D3D12/Vulkan/Metal backends in PAL.

pub mod batch2d;
pub mod cull3d;
pub mod forward3d;
pub mod mesh3d;
pub mod terrain_mesh;

pub use batch2d::{Batch2DSprite, SpriteBatch2D};
pub use forward3d::Forward3DFrame;
pub use mesh3d::Mesh3d;

#[derive(Clone, Copy, Debug)]
pub struct Color {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

impl Color {
    pub fn from_rgba8(rgba: u32) -> Self {
        Self {
            r: ((rgba >> 24) & 0xFF) as f32 / 255.0,
            g: ((rgba >> 16) & 0xFF) as f32 / 255.0,
            b: ((rgba >> 8) & 0xFF) as f32 / 255.0,
            a: (rgba & 0xFF) as f32 / 255.0,
        }
    }
}

pub struct RenderDevice {
    pub backend_name: &'static str,
}

impl RenderDevice {
    pub fn new_stub() -> Self {
        Self {
            backend_name: "stub",
        }
    }

    pub fn begin_frame(&mut self) {}
    pub fn end_frame(&mut self) {}
}
