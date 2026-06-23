//! Platform Abstraction Layer — окно, ввод, GPU surface (stub → Win32/D3D12).

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PlatformKind {
    Windows,
    Linux,
    Android,
    Ios,
    WebWasm,
    Unknown,
}

pub struct Platform {
    pub kind: PlatformKind,
}

impl Platform {
    pub fn detect() -> Self {
        #[cfg(target_os = "windows")]
        let kind = PlatformKind::Windows;
        #[cfg(target_os = "linux")]
        let kind = PlatformKind::Linux;
        #[cfg(target_os = "android")]
        let kind = PlatformKind::Android;
        #[cfg(target_os = "ios")]
        let kind = PlatformKind::Ios;
        #[cfg(target_arch = "wasm32")]
        let kind = PlatformKind::WebWasm;
        #[cfg(not(any(
            target_os = "windows",
            target_os = "linux",
            target_os = "android",
            target_os = "ios",
            target_arch = "wasm32"
        )))]
        let kind = PlatformKind::Unknown;

        Self { kind }
    }

    /// M1: демо-окно D3D12 (только Windows + feature `pal_win_d3d12`).
    #[cfg(all(windows, feature = "pal_win_d3d12"))]
    pub fn run_m1_demo(
        opts: crate::pal::M1DemoOptions,
    ) -> Result<crate::pal::M1DemoResult, String> {
        crate::pal::run_m1_window_demo(opts)
    }

    /// M6a: WebGPU surface stub (wasm32).
    #[cfg(target_arch = "wasm32")]
    pub fn init_wasm_surface(width: u32, height: u32) -> Result<crate::pal::WasmSurface, String> {
        crate::pal::init_webgpu_stub(width, height)
    }
}
