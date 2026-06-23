//! WASM PAL (M6a): stub окна + WebGPU surface для сборки `wasm32-unknown-unknown`.

#[derive(Clone, Copy, Debug)]
pub struct WasmSurface {
    pub width: u32,
    pub height: u32,
}

/// Инициализация WebGPU surface (заглушка до полного PAL).
pub fn init_webgpu_stub(width: u32, height: u32) -> Result<WasmSurface, String> {
    if width == 0 || height == 0 {
        return Err("invalid surface size".into());
    }
    Ok(WasmSurface { width, height })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn webgpu_stub_ok() {
        let s = init_webgpu_stub(800, 600).unwrap();
        assert_eq!(s.width, 800);
    }
}
