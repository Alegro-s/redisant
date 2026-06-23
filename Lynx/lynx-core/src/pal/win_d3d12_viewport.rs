//! M-Q3: встраиваемый D3D12 viewport (child HWND) для Flutter Player.

use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};

use windows::core::PCWSTR;
use windows::Win32::Foundation::{HWND, LPARAM, LRESULT, RECT, WPARAM};
use windows::Win32::Graphics::Dxgi::Common::*;
use windows::Win32::System::LibraryLoader::GetModuleHandleW;
use windows::Win32::UI::WindowsAndMessaging::*;

use crate::render::forward3d::Forward3DFrame;
use crate::render::Color;
use crate::scene3d::{parse_extension, parse_extension_from_scene_json};

use super::win_d3d12::Dx12State;
use super::win_d3d12_forward3d::present_frame_with_forward3d;

static VIEWPORT_CLASS_REGISTERED: AtomicBool = AtomicBool::new(false);

pub struct CoreViewport {
    pub child_hwnd: HWND,
    pub(crate) dx: Dx12State,
}

pub unsafe fn viewport_create_raw(
    parent_hwnd: isize,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) -> Result<Box<CoreViewport>, String> {
    viewport_create(HWND(parent_hwnd as *mut _), x, y, width, height)
}

pub unsafe fn viewport_create(
    parent: HWND,
    x: i32,
    y: i32,
    width: u32,
    height: u32,
) -> Result<Box<CoreViewport>, String> {
    let w = width.max(64);
    let h = height.max(64);
    register_viewport_class()?;
    let instance = GetModuleHandleW(None).map_err(|e| e.to_string())?;
    let child = CreateWindowExW(
        WINDOW_EX_STYLE::default(),
        viewport_class_name(),
        PCWSTR::null(),
        WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS,
        x,
        y,
        w as i32,
        h as i32,
        parent,
        None,
        instance,
        None,
    )
    .map_err(|e| e.to_string())?;
    let dx = super::win_d3d12::init_d3d12(child, w, h)?;
    Ok(Box::new(CoreViewport {
        child_hwnd: child,
        dx,
    }))
}

pub unsafe fn viewport_destroy(vp: *mut CoreViewport) {
    if vp.is_null() {
        return;
    }
    let boxed = Box::from_raw(vp);
    let _ = DestroyWindow(boxed.child_hwnd);
}

pub unsafe fn viewport_resize(vp: &mut CoreViewport, width: u32, height: u32) -> Result<(), String> {
    let w = width.max(64);
    let h = height.max(64);
    if w == vp.dx.width && h == vp.dx.height {
        return Ok(());
    }
    let mut rect = RECT::default();
    let _ = GetWindowRect(vp.child_hwnd, &mut rect);
    let _ = MoveWindow(
        vp.child_hwnd,
        rect.left,
        rect.top,
        w as i32,
        h as i32,
        true,
    );
    resize_swapchain(&mut vp.dx, w, h)?;
    Ok(())
}

pub unsafe fn viewport_present_lynx3d_json(
    vp: &mut CoreViewport,
    json: &str,
    project_root: Option<&Path>,
    orbit_yaw_rad: f32,
    orbit_pitch_rad: f32,
) -> Result<(), String> {
    let scene = if json.contains("\"extensions\"") {
        parse_extension_from_scene_json(json)?
    } else {
        let v: serde_json::Value = serde_json::from_str(json).map_err(|e| e.to_string())?;
        parse_extension(&v)?
    };
    if !scene.active {
        return Ok(());
    }
    let frame = Forward3DFrame::from_lynx3d_scene_with_assets(
        &scene,
        vp.dx.width,
        vp.dx.height,
        orbit_yaw_rad,
        orbit_pitch_rad,
        project_root,
    );
    let clear = Color {
        r: 0.06,
        g: 0.09,
        b: 0.14,
        a: 1.0,
    };
    present_frame_with_forward3d(&mut vp.dx, &clear, &frame)
}

unsafe extern "system" fn viewport_def_wndproc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    DefWindowProcW(hwnd, msg, wparam, lparam)
}

unsafe fn register_viewport_class() -> Result<(), String> {
    if VIEWPORT_CLASS_REGISTERED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }
    let instance = GetModuleHandleW(None).map_err(|e| e.to_string())?;
    let wc = WNDCLASSW {
        style: CS_HREDRAW | CS_VREDRAW,
        lpfnWndProc: Some(viewport_def_wndproc),
        hInstance: instance.into(),
        hCursor: LoadCursorW(None, IDC_ARROW).map_err(|e| e.to_string())?,
        lpszClassName: viewport_class_name(),
        ..Default::default()
    };
    RegisterClassW(&wc);
    Ok(())
}

fn viewport_class_name() -> PCWSTR {
    windows::core::w!("LynxCoreViewportChild")
}

unsafe fn resize_swapchain(dx: &mut Dx12State, width: u32, height: u32) -> Result<(), String> {
    use windows::Win32::Graphics::Direct3D12::ID3D12Resource;
    use windows::Win32::Graphics::Dxgi::DXGI_SWAP_CHAIN_FLAG;

    super::win_d3d12::wait_for_fence(dx)?;
    dx.width = width;
    dx.height = height;
    dx.swap_chain
        .ResizeBuffers(
            2,
            width,
            height,
            DXGI_FORMAT_R8G8B8A8_UNORM,
            DXGI_SWAP_CHAIN_FLAG(0),
        )
        .map_err(|e| e.to_string())?;
    let buf0: ID3D12Resource = dx.swap_chain.GetBuffer(0).map_err(|e| e.to_string())?;
    let buf1: ID3D12Resource = dx.swap_chain.GetBuffer(1).map_err(|e| e.to_string())?;
    let mut rtv = dx.rtv_heap.GetCPUDescriptorHandleForHeapStart();
    dx.device.CreateRenderTargetView(&buf0, None, rtv);
    rtv.ptr = rtv.ptr.wrapping_add(dx.rtv_stride as usize);
    dx.device.CreateRenderTargetView(&buf1, None, rtv);
    dx.back_buffers = [buf0, buf1];
    dx.frame_index = dx.swap_chain.GetCurrentBackBufferIndex();
    Ok(())
}
