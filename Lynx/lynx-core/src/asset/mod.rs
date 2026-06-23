//! Формат `.lynxpack` и импорт ассетов.

pub mod glb_minimal;
pub mod glb_skin;
pub mod texture_rgba8;

pub const LYNXPACK_MAGIC: &[u8; 4] = b"LYNX";

pub struct LynxPackHeader {
    pub version: u32,
}
