//! M1/M2: Win32 окно + D3D12 clear + Present; M2 — 2D batch.

use std::mem::ManuallyDrop;
use std::sync::atomic::{AtomicBool, Ordering};

use windows::core::{Interface, PCWSTR};
use windows::Win32::Foundation::{HWND, LPARAM, LRESULT, WPARAM};
use windows::Win32::Graphics::Direct3D::D3D_FEATURE_LEVEL_11_0;
use windows::Win32::Graphics::Direct3D12::{D3D12CreateDevice, *};
use windows::Win32::Graphics::Dxgi::Common::*;
use windows::Win32::Graphics::Dxgi::*;
use windows::Win32::System::LibraryLoader::GetModuleHandleW;
use windows::Win32::System::Threading::{CreateEventW, WaitForSingleObject, INFINITE};
use windows::Win32::UI::WindowsAndMessaging::*;

use crate::render::batch2d::SpriteBatch2D;
use crate::render::forward3d::Forward3DFrame;
use crate::render::Color;
use crate::scene3d::Lynx3dScene;

static QUIT: AtomicBool = AtomicBool::new(false);

#[derive(Clone, Debug)]
pub struct M1DemoOptions {
    pub width: u32,
    pub height: u32,
    pub title: String,
    pub max_frames: Option<u64>,
    pub clear_color: Color,
}

impl Default for M1DemoOptions {
    fn default() -> Self {
        Self {
            width: 1280,
            height: 720,
            title: "Lynx Core M1 — D3D12".into(),
            max_frames: None,
            clear_color: Color {
                r: 0.08,
                g: 0.12,
                b: 0.22,
                a: 1.0,
            },
        }
    }
}

#[derive(Clone, Debug)]
pub struct M1DemoResult {
    pub frames_presented: u64,
    pub backend: &'static str,
}

pub(crate) struct Dx12State {
    #[allow(dead_code)]
    pub(crate) device: ID3D12Device,
    pub(crate) queue: ID3D12CommandQueue,
    pub(crate) allocator: ID3D12CommandAllocator,
    pub(crate) list: ID3D12GraphicsCommandList,
    pub(crate) rtv_heap: ID3D12DescriptorHeap,
    pub(crate) rtv_stride: u32,
    pub(crate) swap_chain: IDXGISwapChain3,
    pub(crate) back_buffers: [ID3D12Resource; 2],
    pub(crate) frame_index: u32,
    pub(crate) fence: ID3D12Fence,
    pub(crate) fence_value: u64,
    pub(crate) fence_event: windows::Win32::Foundation::HANDLE,
    pub(crate) batch_pipeline: Option<super::win_d3d12_batch::Batch2DPipeline>,
    pub(crate) forward3d: Option<super::win_d3d12_forward3d::Forward3DPipeline>,
    pub(crate) width: u32,
    pub(crate) height: u32,
}

fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

pub fn run_m1_window_demo(opts: M1DemoOptions) -> Result<M1DemoResult, String> {
    QUIT.store(false, Ordering::SeqCst);
    unsafe {
        let instance = GetModuleHandleW(None).map_err(|e| e.to_string())?;
        let class_name = windows::core::w!("LynxCoreM1Window");

        let wc = WNDCLASSW {
            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(window_proc),
            hInstance: instance.into(),
            hCursor: LoadCursorW(None, IDC_ARROW).map_err(|e| e.to_string())?,
            lpszClassName: class_name,
            ..Default::default()
        };
        RegisterClassW(&wc);

        let title_wide = wide(&opts.title);
        let hwnd = CreateWindowExW(
            WINDOW_EX_STYLE::default(),
            class_name,
            PCWSTR(title_wide.as_ptr()),
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            opts.width as i32,
            opts.height as i32,
            None,
            None,
            instance,
            None,
        )
        .map_err(|e| e.to_string())?;

        let mut dx = init_d3d12(hwnd, opts.width, opts.height)?;
        let _ = ShowWindow(hwnd, SW_SHOW);

        let mut msg = MSG::default();
        let mut frames: u64 = 0;
        let clear = opts.clear_color;

        loop {
            while PeekMessageW(&mut msg, None, 0, 0, PM_REMOVE).into() {
                if msg.message == WM_QUIT {
                    QUIT.store(true, Ordering::SeqCst);
                }
                let _ = TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
            if QUIT.load(Ordering::SeqCst) {
                break;
            }

            super::win_d3d12_batch::present_frame_with_batch(
                &mut dx,
                &clear,
                None,
                (opts.width, opts.height),
            )?;
            frames += 1;

            if let Some(max) = opts.max_frames {
                if frames >= max {
                    let _ = PostQuitMessage(0);
                    break;
                }
            }
        }

        Ok(M1DemoResult {
            frames_presented: frames,
            backend: "D3D12",
        })
    }
}

unsafe extern "system" fn window_proc(
    hwnd: HWND,
    msg: u32,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    match msg {
        WM_DESTROY => {
            let _ = PostQuitMessage(0);
            LRESULT(0)
        }
        WM_KEYDOWN if wparam.0 == 0x1B => {
            let _ = PostQuitMessage(0);
            LRESULT(0)
        }
        _ => DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

pub(crate) unsafe fn init_d3d12(hwnd: HWND, width: u32, height: u32) -> Result<Dx12State, String> {
    let mut device: Option<ID3D12Device> = None;
    D3D12CreateDevice(None, D3D_FEATURE_LEVEL_11_0, &mut device)
        .map_err(|e| e.to_string())?;
    let device = device.ok_or("D3D12CreateDevice returned null")?;

    let queue: ID3D12CommandQueue = device
        .CreateCommandQueue(&D3D12_COMMAND_QUEUE_DESC {
            Type: D3D12_COMMAND_LIST_TYPE_DIRECT,
            ..Default::default()
        })
        .map_err(|e| e.to_string())?;

    let factory: IDXGIFactory4 = CreateDXGIFactory2(DXGI_CREATE_FACTORY_FLAGS::default())
        .map_err(|e| e.to_string())?;

    let swap_chain_desc = DXGI_SWAP_CHAIN_DESC1 {
        Width: width,
        Height: height,
        Format: DXGI_FORMAT_R8G8B8A8_UNORM,
        BufferUsage: DXGI_USAGE_RENDER_TARGET_OUTPUT,
        BufferCount: 2,
        SwapEffect: DXGI_SWAP_EFFECT_FLIP_DISCARD,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        ..Default::default()
    };

    let swap_chain1: IDXGISwapChain1 = factory
        .CreateSwapChainForHwnd(&queue, hwnd, &swap_chain_desc, None, None)
        .map_err(|e| e.to_string())?;
    let swap_chain: IDXGISwapChain3 = swap_chain1.cast().map_err(|e| e.to_string())?;
    let _ = factory.MakeWindowAssociation(hwnd, DXGI_MWA_NO_ALT_ENTER);

    let rtv_heap: ID3D12DescriptorHeap = device
        .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
            Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
            NumDescriptors: 2,
            Flags: D3D12_DESCRIPTOR_HEAP_FLAGS(0),
            ..Default::default()
        })
        .map_err(|e| e.to_string())?;
    let rtv_stride = device.GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

    let buf0: ID3D12Resource = swap_chain.GetBuffer(0).map_err(|e| e.to_string())?;
    let buf1: ID3D12Resource = swap_chain.GetBuffer(1).map_err(|e| e.to_string())?;
    let mut rtv_handle = rtv_heap.GetCPUDescriptorHandleForHeapStart();
    device.CreateRenderTargetView(&buf0, None, rtv_handle);
    rtv_handle.ptr = rtv_handle.ptr.wrapping_add(rtv_stride as usize);
    device.CreateRenderTargetView(&buf1, None, rtv_handle);
    let back_buffers = [buf0, buf1];

    let allocator: ID3D12CommandAllocator = device
        .CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)
        .map_err(|e| e.to_string())?;
    let list: ID3D12GraphicsCommandList = device
        .CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, &allocator, None)
        .map_err(|e| e.to_string())?;
    list.Close().map_err(|e| e.to_string())?;

    let fence: ID3D12Fence = device
        .CreateFence(0, D3D12_FENCE_FLAGS::default())
        .map_err(|e| e.to_string())?;
    let fence_event =
        CreateEventW(None, false, false, None).map_err(|e| e.to_string())?;

    let frame_index = swap_chain.GetCurrentBackBufferIndex();
    let batch_pipeline =
        super::win_d3d12_batch::init_batch2d_pipeline(&device, DXGI_FORMAT_R8G8B8A8_UNORM).ok();
    let forward3d = super::win_d3d12_forward3d::init_forward3d_pipeline(
        &device,
        &queue,
        &allocator,
        width,
        height,
    )
    .ok();
    Ok(Dx12State {
        device,
        queue,
        allocator,
        list,
        rtv_heap,
        rtv_stride,
        swap_chain,
        back_buffers,
        frame_index,
        fence,
        fence_value: 0,
        fence_event,
        batch_pipeline,
        forward3d,
        width,
        height,
    })
}

#[derive(Clone, Debug)]
pub struct M2DemoOptions {
    pub width: u32,
    pub height: u32,
    pub title: String,
    pub max_frames: Option<u64>,
    pub clear_color: Color,
}

impl Default for M2DemoOptions {
    fn default() -> Self {
        Self {
            width: 1280,
            height: 720,
            title: "Lynx Core M2 — 2D Batch (D3D12)".into(),
            max_frames: None,
            clear_color: Color {
                r: 0.05,
                g: 0.07,
                b: 0.12,
                a: 1.0,
            },
        }
    }
}

#[derive(Clone, Debug)]
pub struct M2DemoResult {
    pub frames_presented: u64,
    pub backend: &'static str,
}

/// M2: окно + clear + отрисовка [`SpriteBatch2D`].
pub fn run_m2_window_demo(opts: M2DemoOptions, mut batch: SpriteBatch2D) -> Result<M2DemoResult, String> {
    QUIT.store(false, Ordering::SeqCst);
    unsafe {
        let instance = GetModuleHandleW(None).map_err(|e| e.to_string())?;
        let class_name = windows::core::w!("LynxCoreM2Window");

        let wc = WNDCLASSW {
            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(window_proc),
            hInstance: instance.into(),
            hCursor: LoadCursorW(None, IDC_ARROW).map_err(|e| e.to_string())?,
            lpszClassName: class_name,
            ..Default::default()
        };
        RegisterClassW(&wc);

        let title_wide = wide(&opts.title);
        let hwnd = CreateWindowExW(
            WINDOW_EX_STYLE::default(),
            class_name,
            PCWSTR(title_wide.as_ptr()),
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            opts.width as i32,
            opts.height as i32,
            None,
            None,
            instance,
            None,
        )
        .map_err(|e| e.to_string())?;

        let mut dx = init_d3d12(hwnd, opts.width, opts.height)?;
        let _ = ShowWindow(hwnd, SW_SHOW);

        let mut msg = MSG::default();
        let mut frames: u64 = 0;
        let clear = opts.clear_color;
        let vp = (opts.width, opts.height);

        loop {
            while PeekMessageW(&mut msg, None, 0, 0, PM_REMOVE).into() {
                if msg.message == WM_QUIT {
                    QUIT.store(true, Ordering::SeqCst);
                }
                let _ = TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
            if QUIT.load(Ordering::SeqCst) {
                break;
            }

            batch.clear();
            let t = frames as f32 * 0.04;
            let _ = batch.push_center_rect(
                opts.width as f32 * 0.5 + t.cos() * 120.0,
                opts.height as f32 * 0.5 + t.sin() * 80.0,
                160.0,
                96.0,
                0xFF_33_AA_FF,
            );
            let _ = batch.push_center_rect(180.0, 180.0, 80.0, 80.0, 0xFF_FF_CC_44);
            let _ = batch.push_center_rect(
                opts.width as f32 - 200.0,
                opts.height as f32 - 160.0,
                120.0,
                60.0,
                0xCC_FF_66_99,
            );

            super::win_d3d12_batch::present_frame_with_batch(
                &mut dx,
                &clear,
                Some(&mut batch),
                vp,
            )?;
            frames += 1;

            if let Some(max) = opts.max_frames {
                if frames >= max {
                    let _ = PostQuitMessage(0);
                    break;
                }
            }
        }

        Ok(M2DemoResult {
            frames_presented: frames,
            backend: "D3D12+Batch2D",
        })
    }
}

#[derive(Clone, Debug)]
pub struct M3DemoOptions {
    pub width: u32,
    pub height: u32,
    pub title: String,
    pub max_frames: Option<u64>,
    pub clear_color: Color,
    pub project_root: Option<std::path::PathBuf>,
}

impl Default for M3DemoOptions {
    fn default() -> Self {
        Self {
            width: 1280,
            height: 720,
            title: "Lynx Core M3 — Forward 3D PBR".into(),
            max_frames: None,
            clear_color: Color {
                r: 0.04,
                g: 0.05,
                b: 0.08,
                a: 1.0,
            },
            project_root: None,
        }
    }
}

#[derive(Clone, Debug)]
pub struct M3DemoResult {
    pub frames_presented: u64,
    pub backend: &'static str,
}

/// M3: `extensions.lynx.3d` → forward PBR-lite на D3D12.
pub fn run_m3_window_demo(
    opts: M3DemoOptions,
    scene: Lynx3dScene,
) -> Result<M3DemoResult, String> {
    if !scene.active {
        return Err("lynx.3d scene not active".into());
    }
    QUIT.store(false, Ordering::SeqCst);
    unsafe {
        let instance = GetModuleHandleW(None).map_err(|e| e.to_string())?;
        let class_name = windows::core::w!("LynxCoreM3Window");
        let wc = WNDCLASSW {
            style: CS_HREDRAW | CS_VREDRAW,
            lpfnWndProc: Some(window_proc),
            hInstance: instance.into(),
            hCursor: LoadCursorW(None, IDC_ARROW).map_err(|e| e.to_string())?,
            lpszClassName: class_name,
            ..Default::default()
        };
        RegisterClassW(&wc);
        let title_wide = wide(&opts.title);
        let hwnd = CreateWindowExW(
            WINDOW_EX_STYLE::default(),
            class_name,
            PCWSTR(title_wide.as_ptr()),
            WS_OVERLAPPEDWINDOW | WS_VISIBLE,
            CW_USEDEFAULT,
            CW_USEDEFAULT,
            opts.width as i32,
            opts.height as i32,
            None,
            None,
            instance,
            None,
        )
        .map_err(|e| e.to_string())?;
        let mut dx = init_d3d12(hwnd, opts.width, opts.height)?;
        let _ = ShowWindow(hwnd, SW_SHOW);
        let mut msg = MSG::default();
        let mut frames: u64 = 0;
        let clear = opts.clear_color;
        loop {
            while PeekMessageW(&mut msg, None, 0, 0, PM_REMOVE).into() {
                if msg.message == WM_QUIT {
                    QUIT.store(true, Ordering::SeqCst);
                }
                let _ = TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
            if QUIT.load(Ordering::SeqCst) {
                break;
            }
            let yaw = frames as f32 * 0.012;
            let pitch = 0.35;
            let root = opts.project_root.as_deref();
            let frame = Forward3DFrame::from_lynx3d_scene_with_assets(
                &scene,
                opts.width,
                opts.height,
                yaw,
                pitch,
                root,
            );
            super::win_d3d12_forward3d::present_frame_with_forward3d(&mut dx, &clear, &frame)?;
            frames += 1;
            if let Some(max) = opts.max_frames {
                if frames >= max {
                    let _ = PostQuitMessage(0);
                    break;
                }
            }
        }
        Ok(M3DemoResult {
            frames_presented: frames,
            backend: "D3D12+Forward3D",
        })
    }
}

pub(crate) unsafe fn transition(
    list: &ID3D12GraphicsCommandList,
    resource: &ID3D12Resource,
    before: D3D12_RESOURCE_STATES,
    after: D3D12_RESOURCE_STATES,
) {
    let barrier = D3D12_RESOURCE_BARRIER {
        Type: D3D12_RESOURCE_BARRIER_TYPE_TRANSITION,
        Flags: D3D12_RESOURCE_BARRIER_FLAGS(0),
        Anonymous: D3D12_RESOURCE_BARRIER_0 {
            Transition: ManuallyDrop::new(D3D12_RESOURCE_TRANSITION_BARRIER {
                pResource: ManuallyDrop::new(Some(resource.clone())),
                Subresource: D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                StateBefore: before,
                StateAfter: after,
            }),
        },
    };
    list.ResourceBarrier(&[barrier]);
}

pub(crate) unsafe fn wait_for_fence(dx: &mut Dx12State) -> Result<(), String> {
    dx.fence_value += 1;
    dx.queue
        .Signal(&dx.fence, dx.fence_value)
        .map_err(|e| e.to_string())?;
    if dx.fence.GetCompletedValue() < dx.fence_value {
        dx.fence
            .SetEventOnCompletion(dx.fence_value, dx.fence_event)
            .map_err(|e| e.to_string())?;
        let _ = WaitForSingleObject(dx.fence_event, INFINITE);
    }
    Ok(())
}
