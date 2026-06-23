//! M3: D3D12 forward 3D (depth + directional PBR-lite). M12b: albedo SRV + per-mesh VB.

use std::collections::HashMap;
use std::ffi::c_void;
use std::mem::ManuallyDrop;
use std::ptr;

use windows::core::Interface;
use windows::Win32::Graphics::Direct3D::*;
use windows::Win32::Graphics::Direct3D12::*;
use windows::Win32::System::Threading::{CreateEventW, WaitForSingleObject, INFINITE};
use windows::Win32::Graphics::Dxgi::Common::{
    DXGI_FORMAT, DXGI_FORMAT_D32_FLOAT, DXGI_FORMAT_R32_FLOAT, DXGI_FORMAT_R32G32_FLOAT,
    DXGI_FORMAT_R32G32B32_FLOAT, DXGI_FORMAT_R32_UINT, DXGI_FORMAT_R8G8B8A8_UNORM,
    DXGI_FORMAT_UNKNOWN, DXGI_SAMPLE_DESC,
};

use crate::asset::texture_rgba8::Rgba8Image;
use crate::render::forward3d::{Forward3DDraw, Forward3DFrame, Vertex3d};
use crate::render::mesh3d::Mesh3d;
use crate::render::Color;

const VS_BYTECODE: &[u8] = include_bytes!("../../assets/shaders/forward3d_vs.cso");
const PS_BYTECODE: &[u8] = include_bytes!("../../assets/shaders/forward3d_ps.cso");
const SHADOW_VS_BYTECODE: &[u8] = include_bytes!("../../assets/shaders/forward3d_shadow_vs.cso");
const SHADOW_PS_BYTECODE: &[u8] = include_bytes!("../../assets/shaders/forward3d_shadow_ps.cso");

const CB_ALIGN: usize = 256;
const SHADOW_SIZE: u32 = crate::render::forward3d::SHADOW_MAP_SIZE;
const SRV_HEAP_SIZE: u32 = 64;
const SRV_SHADOW_INDEX: u32 = 0;
const SRV_DEFAULT_ALBEDO_INDEX: u32 = 1;
const SRV_SHADOW_C1_INDEX: u32 = 2;

#[repr(C)]
struct FrameCB {
    view_proj: [[f32; 4]; 4],
    light_view_proj: [[f32; 4]; 4],
    light_view_proj_c1: [[f32; 4]; 4],
    light_dir: [f32; 4],
    ambient: [f32; 4],
    camera_pos: [f32; 4],
    shadow_params: [f32; 4],
    cascade_flags: [f32; 4],
    render_params: [f32; 4],
}

#[repr(C)]
struct ObjectCB {
    model: [[f32; 4]; 4],
    base_color: [f32; 4],
    metallic: f32,
    roughness: f32,
    use_albedo: f32,
    use_normal: f32,
}

struct CachedGpuMesh {
    vb: ID3D12Resource,
    ib: ID3D12Resource,
    index_count: u32,
}

struct CachedGpuTexture {
    texture: ID3D12Resource,
    srv_index: u32,
}

pub struct Forward3DPipeline {
    root_sig: ID3D12RootSignature,
    pso: ID3D12PipelineState,
    shadow_pso: ID3D12PipelineState,
    queue: ID3D12CommandQueue,
    copy_allocator: ID3D12CommandAllocator,
    cb_upload: ID3D12Resource,
    dsv_heap: ID3D12DescriptorHeap,
    depth: ID3D12Resource,
    shadow_map: ID3D12Resource,
    shadow_map_c1: ID3D12Resource,
    shadow_rtv_heap: ID3D12DescriptorHeap,
    shadow_rtv_stride: u32,
    srv_heap: ID3D12DescriptorHeap,
    srv_stride: u32,
    mesh_cache: HashMap<u64, CachedGpuMesh>,
    texture_cache: HashMap<u64, CachedGpuTexture>,
    next_srv_index: u32,
}

pub unsafe fn init_forward3d_pipeline(
    device: &ID3D12Device,
    queue: &ID3D12CommandQueue,
    allocator: &ID3D12CommandAllocator,
    width: u32,
    height: u32,
) -> Result<Forward3DPipeline, String> {
    let root_sig = create_root_signature(device)?;
    let pso = create_pso(
        device,
        &root_sig,
        VS_BYTECODE,
        PS_BYTECODE,
        DXGI_FORMAT_R8G8B8A8_UNORM,
        true,
    )?;
    let shadow_pso = create_pso(
        device,
        &root_sig,
        SHADOW_VS_BYTECODE,
        SHADOW_PS_BYTECODE,
        DXGI_FORMAT_R32_FLOAT,
        false,
    )?;
    let cb_upload = create_upload_buffer(device, (CB_ALIGN * 64) as u64)?;
    let dsv_heap: ID3D12DescriptorHeap = device
        .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
            Type: D3D12_DESCRIPTOR_HEAP_TYPE_DSV,
            NumDescriptors: 1,
            Flags: D3D12_DESCRIPTOR_HEAP_FLAGS(0),
            ..Default::default()
        })
        .map_err(|e| e.to_string())?;
    let depth = create_depth_texture(device, width, height)?;
    let dsv = dsv_heap.GetCPUDescriptorHandleForHeapStart();
    device.CreateDepthStencilView(&depth, None, dsv);

    let shadow_map = create_shadow_map(device)?;
    let shadow_map_c1 = create_shadow_map(device)?;
    let shadow_rtv_heap: ID3D12DescriptorHeap = device
        .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
            Type: D3D12_DESCRIPTOR_HEAP_TYPE_RTV,
            NumDescriptors: 2,
            Flags: D3D12_DESCRIPTOR_HEAP_FLAGS(0),
            ..Default::default()
        })
        .map_err(|e| e.to_string())?;
    let shadow_rtv_stride =
        device.GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    let shadow_rtv = shadow_rtv_heap.GetCPUDescriptorHandleForHeapStart();
    device.CreateRenderTargetView(&shadow_map, None, shadow_rtv);
    let mut shadow_rtv1 = shadow_rtv;
    shadow_rtv1.ptr = shadow_rtv1
        .ptr
        .wrapping_add(shadow_rtv_stride as usize);
    device.CreateRenderTargetView(&shadow_map_c1, None, shadow_rtv1);

    let srv_heap: ID3D12DescriptorHeap = device
        .CreateDescriptorHeap(&D3D12_DESCRIPTOR_HEAP_DESC {
            Type: D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
            NumDescriptors: SRV_HEAP_SIZE,
            Flags: D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE,
            ..Default::default()
        })
        .map_err(|e| e.to_string())?;
    let srv_stride = device.GetDescriptorHandleIncrementSize(
        D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,
    );
    let srv_cpu = srv_heap.GetCPUDescriptorHandleForHeapStart();
    device.CreateShaderResourceView(
        &shadow_map,
        Some(&D3D12_SHADER_RESOURCE_VIEW_DESC {
            Format: DXGI_FORMAT_R32_FLOAT,
            ViewDimension: D3D12_SRV_DIMENSION_TEXTURE2D,
            Shader4ComponentMapping: D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
            Anonymous: D3D12_SHADER_RESOURCE_VIEW_DESC_0 {
                Texture2D: D3D12_TEX2D_SRV {
                    MipLevels: 1,
                    ..Default::default()
                },
            },
        }),
        srv_cpu,
    );
    let white = Rgba8Image {
        width: 1,
        height: 1,
        pixels: vec![255, 255, 255, 255],
    };
    let white_tex = create_texture_rgba8(device, queue, allocator, &white)?;
    let mut albedo_cpu = srv_cpu;
    albedo_cpu.ptr = albedo_cpu.ptr.wrapping_add(srv_stride as usize);
    create_srv_for_texture(device, &white_tex, albedo_cpu)?;
    let mut c1_cpu = srv_cpu;
    c1_cpu.ptr = c1_cpu
        .ptr
        .wrapping_add(SRV_SHADOW_C1_INDEX as usize * srv_stride as usize);
    device.CreateShaderResourceView(
        &shadow_map_c1,
        Some(&D3D12_SHADER_RESOURCE_VIEW_DESC {
            Format: DXGI_FORMAT_R32_FLOAT,
            ViewDimension: D3D12_SRV_DIMENSION_TEXTURE2D,
            Shader4ComponentMapping: D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
            Anonymous: D3D12_SHADER_RESOURCE_VIEW_DESC_0 {
                Texture2D: D3D12_TEX2D_SRV {
                    MipLevels: 1,
                    ..Default::default()
                },
            },
        }),
        c1_cpu,
    );

    let copy_allocator: ID3D12CommandAllocator = device
        .CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT)
        .map_err(|e| e.to_string())?;
    let mut pipe = Forward3DPipeline {
        root_sig,
        pso,
        shadow_pso,
        queue: queue.clone(),
        copy_allocator,
        cb_upload,
        dsv_heap,
        depth,
        shadow_map,
        shadow_map_c1,
        shadow_rtv_heap,
        shadow_rtv_stride,
        srv_heap,
        srv_stride,
        mesh_cache: HashMap::new(),
        texture_cache: HashMap::new(),
        next_srv_index: 3,
    };
    let cube = Mesh3d::unit_cube();
    let key = 0u64;
    let _ = ensure_gpu_mesh(device, &mut pipe, key, &cube);
    Ok(pipe)
}

pub unsafe fn resize_depth(
    device: &ID3D12Device,
    pipe: &mut Forward3DPipeline,
    width: u32,
    height: u32,
) -> Result<(), String> {
    pipe.depth = create_depth_texture(device, width, height)?;
    let dsv = pipe.dsv_heap.GetCPUDescriptorHandleForHeapStart();
    device.CreateDepthStencilView(&pipe.depth, None, dsv);
    Ok(())
}

pub unsafe fn draw_forward3d(
    list: &ID3D12GraphicsCommandList,
    device: &ID3D12Device,
    pipe: &mut Forward3DPipeline,
    rtv: D3D12_CPU_DESCRIPTOR_HANDLE,
    dsv: D3D12_CPU_DESCRIPTOR_HANDLE,
    viewport: (u32, u32),
    frame: &Forward3DFrame,
) -> Result<(), String> {
    prepare_frame_gpu_assets(device, pipe, frame)?;
    list.SetGraphicsRootSignature(&pipe.root_sig);
    list.SetPipelineState(&pipe.shadow_pso);
    render_shadow_pass(list, pipe, frame, 0)?;
    if frame.shadow.enable_cascade {
        render_shadow_pass(list, pipe, frame, 1)?;
    }

    let srv_gpu = pipe.srv_heap.GetGPUDescriptorHandleForHeapStart();
    list.SetDescriptorHeaps(&[Some(pipe.srv_heap.clone())]);
    list.SetGraphicsRootDescriptorTable(2, srv_gpu);

    let vp = D3D12_VIEWPORT {
        TopLeftX: 0.0,
        TopLeftY: 0.0,
        Width: viewport.0 as f32,
        Height: viewport.1 as f32,
        MinDepth: 0.0,
        MaxDepth: 1.0,
    };
    let scissor = windows::Win32::Foundation::RECT {
        left: 0,
        top: 0,
        right: viewport.0 as i32,
        bottom: viewport.1 as i32,
    };
    list.RSSetViewports(&[vp]);
    list.RSSetScissorRects(&[scissor]);
    list.OMSetRenderTargets(1, Some(&rtv), None, Some(&dsv));
    list.OMSetStencilRef(0);
    list.ClearDepthStencilView(dsv, D3D12_CLEAR_FLAG_DEPTH, 1.0, 0, &[]);
    list.SetPipelineState(&pipe.pso);
    upload_frame_cb(&pipe.cb_upload, frame)?;
    list.SetGraphicsRootConstantBufferView(0, pipe.cb_upload.GetGPUVirtualAddress());
    draw_all(list, device, pipe, frame);
    Ok(())
}

unsafe fn prepare_frame_gpu_assets(
    device: &ID3D12Device,
    pipe: &mut Forward3DPipeline,
    frame: &Forward3DFrame,
) -> Result<(), String> {
    for draw in &frame.draws {
        ensure_gpu_mesh(device, pipe, draw.mesh_key, &draw.mesh)?;
        if draw.albedo_image.is_some() {
            cache_albedo_texture(device, pipe, draw)?;
        }
    }
    Ok(())
}

unsafe fn bind_mesh_ia(list: &ID3D12GraphicsCommandList, mesh: &CachedGpuMesh) {
    let vb_bytes = mesh.vb.GetDesc().Width as u32;
    let vb_view = D3D12_VERTEX_BUFFER_VIEW {
        BufferLocation: mesh.vb.GetGPUVirtualAddress(),
        SizeInBytes: vb_bytes,
        StrideInBytes: std::mem::size_of::<Vertex3d>() as u32,
    };
    let ib_view = D3D12_INDEX_BUFFER_VIEW {
        BufferLocation: mesh.ib.GetGPUVirtualAddress(),
        SizeInBytes: (mesh.index_count * 4) as u32,
        Format: DXGI_FORMAT_R32_UINT,
    };
    list.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    list.IASetVertexBuffers(0, Some(&[vb_view]));
    list.IASetIndexBuffer(Some(&ib_view));
}

unsafe fn draw_casters(
    list: &ID3D12GraphicsCommandList,
    pipe: &Forward3DPipeline,
    frame: &Forward3DFrame,
) {
    let mut slot = 1usize;
    for draw in frame.draws.iter().filter(|d| d.cast_shadow) {
        let Some(mesh) = pipe.mesh_cache.get(&draw.mesh_key) else {
            continue;
        };
        upload_object_cb(&pipe.cb_upload, CB_ALIGN * slot, draw).ok();
        list.SetGraphicsRootConstantBufferView(
            1,
            pipe.cb_upload.GetGPUVirtualAddress() + (CB_ALIGN * slot) as u64,
        );
        bind_mesh_ia(list, mesh);
        list.DrawIndexedInstanced(mesh.index_count, 1, 0, 0, 0);
        slot += 1;
    }
}

unsafe fn draw_all(
    list: &ID3D12GraphicsCommandList,
    device: &ID3D12Device,
    pipe: &mut Forward3DPipeline,
    frame: &Forward3DFrame,
) {
    for (i, draw) in frame.draws.iter().enumerate() {
        let Some(mesh) = pipe.mesh_cache.get(&draw.mesh_key) else {
            continue;
        };
        copy_albedo_to_slot(device, pipe, draw).ok();
        upload_object_cb(&pipe.cb_upload, CB_ALIGN * (1 + i), draw).ok();
        list.SetGraphicsRootConstantBufferView(
            1,
            pipe.cb_upload.GetGPUVirtualAddress() + (CB_ALIGN * (1 + i)) as u64,
        );
        bind_mesh_ia(list, mesh);
        list.DrawIndexedInstanced(mesh.index_count, 1, 0, 0, 0);
    }
}

fn mat4_to_cols(m: &crate::math::Mat4) -> [[f32; 4]; 4] {
    let mut c = [[0.0; 4]; 4];
    for col in 0..4 {
        for row in 0..4 {
            c[col][row] = m.m[col * 4 + row];
        }
    }
    c
}

fn build_frame_cb(frame: &Forward3DFrame, shadow_light: &crate::math::Mat4) -> FrameCB {
    FrameCB {
        view_proj: mat4_to_cols(&frame.view_proj),
        light_view_proj: mat4_to_cols(shadow_light),
        light_view_proj_c1: mat4_to_cols(&frame.light_view_proj_c1),
        light_dir: [
            frame.light.direction.x,
            frame.light.direction.y,
            frame.light.direction.z,
            0.0,
        ],
        ambient: [
            frame.light.ambient[0],
            frame.light.ambient[1],
            frame.light.ambient[2],
            1.0,
        ],
        camera_pos: [
            frame.camera_position.x,
            frame.camera_position.y,
            frame.camera_position.z,
            1.0,
        ],
        shadow_params: [
            frame.shadow.texel_size,
            frame.shadow.depth_bias,
            frame.shadow.penumbra,
            frame.shadow.cascade_split_distance,
        ],
        cascade_flags: [
            if frame.shadow.enable_cascade {
                1.0
            } else {
                0.0
            },
            0.0,
            0.0,
            0.0,
        ],
        render_params: [
            frame.render.ibl_strength,
            frame.render.exposure,
            frame.render.bloom,
            if frame.render.post_enabled { 1.0 } else { 0.0 },
        ],
    }
}

unsafe fn upload_frame_cb(cb: &ID3D12Resource, frame: &Forward3DFrame) -> Result<(), String> {
    let data = build_frame_cb(frame, &frame.light_view_proj);
    write_cb(cb, 0, &data)
}

unsafe fn render_shadow_pass(
    list: &ID3D12GraphicsCommandList,
    pipe: &Forward3DPipeline,
    frame: &Forward3DFrame,
    cascade: u32,
) -> Result<(), String> {
    let mut shadow_rtv = pipe.shadow_rtv_heap.GetCPUDescriptorHandleForHeapStart();
    shadow_rtv.ptr = shadow_rtv.ptr.wrapping_add(
        cascade as usize * pipe.shadow_rtv_stride as usize,
    );
    let shadow_vp = D3D12_VIEWPORT {
        TopLeftX: 0.0,
        TopLeftY: 0.0,
        Width: SHADOW_SIZE as f32,
        Height: SHADOW_SIZE as f32,
        MinDepth: 0.0,
        MaxDepth: 1.0,
    };
    list.RSSetViewports(&[shadow_vp]);
    list.RSSetScissorRects(&[windows::Win32::Foundation::RECT {
        left: 0,
        top: 0,
        right: SHADOW_SIZE as i32,
        bottom: SHADOW_SIZE as i32,
    }]);
    list.OMSetRenderTargets(1, Some(&shadow_rtv), None, None);
    let clear_shadow = [1.0f32, 1.0, 1.0, 1.0];
    list.ClearRenderTargetView(shadow_rtv, &clear_shadow, None);
    let light = if cascade == 0 {
        &frame.light_view_proj
    } else {
        &frame.light_view_proj_c1
    };
    let data = build_frame_cb(frame, light);
    write_cb(&pipe.cb_upload, 0, &data)?;
    list.SetGraphicsRootConstantBufferView(0, pipe.cb_upload.GetGPUVirtualAddress());
    draw_casters(list, pipe, frame);
    Ok(())
}

unsafe fn upload_object_cb(
    cb: &ID3D12Resource,
    offset: usize,
    draw: &crate::render::forward3d::Forward3DDraw,
) -> Result<(), String> {
    let data = ObjectCB {
        model: mat4_to_cols(&draw.model),
        base_color: draw.base_color,
        metallic: draw.metallic,
        roughness: draw.roughness,
        use_albedo: if draw.albedo_image.is_some() { 1.0 } else { 0.0 },
        use_normal: if draw.normal_image.is_some() { 1.0 } else { 0.0 },
    };
    write_cb(cb, offset, &data)
}

unsafe fn write_cb<T>(cb: &ID3D12Resource, offset: usize, data: &T) -> Result<(), String> {
    let mut mapped: *mut c_void = ptr::null_mut();
    cb.Map(0, None, Some(&mut mapped)).map_err(|e| e.to_string())?;
    ptr::copy_nonoverlapping(
        data as *const T as *const u8,
        (mapped as *mut u8).add(offset),
        std::mem::size_of::<T>(),
    );
    cb.Unmap(0, None);
    Ok(())
}

unsafe fn create_root_signature(device: &ID3D12Device) -> Result<ID3D12RootSignature, String> {
    let range = D3D12_DESCRIPTOR_RANGE {
        RangeType: D3D12_DESCRIPTOR_RANGE_TYPE_SRV,
        NumDescriptors: 3,
        BaseShaderRegister: 0,
        RegisterSpace: 0,
        OffsetInDescriptorsFromTableStart: 0,
    };
    let params = [
        D3D12_ROOT_PARAMETER {
            ParameterType: D3D12_ROOT_PARAMETER_TYPE_CBV,
            ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
            Anonymous: D3D12_ROOT_PARAMETER_0 {
                Descriptor: D3D12_ROOT_DESCRIPTOR {
                    ShaderRegister: 0,
                    RegisterSpace: 0,
                },
            },
        },
        D3D12_ROOT_PARAMETER {
            ParameterType: D3D12_ROOT_PARAMETER_TYPE_CBV,
            ShaderVisibility: D3D12_SHADER_VISIBILITY_ALL,
            Anonymous: D3D12_ROOT_PARAMETER_0 {
                Descriptor: D3D12_ROOT_DESCRIPTOR {
                    ShaderRegister: 1,
                    RegisterSpace: 0,
                },
            },
        },
        D3D12_ROOT_PARAMETER {
            ParameterType: D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
            ShaderVisibility: D3D12_SHADER_VISIBILITY_PIXEL,
            Anonymous: D3D12_ROOT_PARAMETER_0 {
                DescriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE {
                    NumDescriptorRanges: 1,
                    pDescriptorRanges: &range,
                },
            },
        },
    ];
    let samplers = [
        D3D12_STATIC_SAMPLER_DESC {
            Filter: D3D12_FILTER_MIN_MAG_MIP_LINEAR,
            AddressU: D3D12_TEXTURE_ADDRESS_MODE_BORDER,
            AddressV: D3D12_TEXTURE_ADDRESS_MODE_BORDER,
            AddressW: D3D12_TEXTURE_ADDRESS_MODE_BORDER,
            ComparisonFunc: D3D12_COMPARISON_FUNC_NEVER,
            BorderColor: D3D12_STATIC_BORDER_COLOR_OPAQUE_WHITE,
            ShaderRegister: 0,
            RegisterSpace: 0,
            ShaderVisibility: D3D12_SHADER_VISIBILITY_PIXEL,
            ..Default::default()
        },
        D3D12_STATIC_SAMPLER_DESC {
            Filter: D3D12_FILTER_MIN_MAG_MIP_LINEAR,
            AddressU: D3D12_TEXTURE_ADDRESS_MODE_WRAP,
            AddressV: D3D12_TEXTURE_ADDRESS_MODE_WRAP,
            AddressW: D3D12_TEXTURE_ADDRESS_MODE_WRAP,
            ComparisonFunc: D3D12_COMPARISON_FUNC_NEVER,
            ShaderRegister: 1,
            RegisterSpace: 0,
            ShaderVisibility: D3D12_SHADER_VISIBILITY_PIXEL,
            ..Default::default()
        },
    ];
    let desc = D3D12_ROOT_SIGNATURE_DESC {
        NumParameters: 3,
        pParameters: params.as_ptr(),
        NumStaticSamplers: 2,
        pStaticSamplers: samplers.as_ptr(),
        Flags: D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
    };
    let mut blob: Option<ID3DBlob> = None;
    let mut err: Option<ID3DBlob> = None;
    D3D12SerializeRootSignature(
        &desc,
        D3D_ROOT_SIGNATURE_VERSION_1,
        &mut blob,
        Some(&mut err),
    )
    .map_err(|e| format!("{e}"))?;
    let blob = blob.ok_or("root sig blob")?;
    device
        .CreateRootSignature(
            0,
            std::slice::from_raw_parts(
                blob.GetBufferPointer() as *const u8,
                blob.GetBufferSize(),
            ),
        )
        .map_err(|e| e.to_string())
}

unsafe fn create_pso(
    device: &ID3D12Device,
    root_sig: &ID3D12RootSignature,
    vs: &[u8],
    ps: &[u8],
    rtv_format: DXGI_FORMAT,
    depth_enable: bool,
) -> Result<ID3D12PipelineState, String> {
    let input = [
        D3D12_INPUT_ELEMENT_DESC {
            SemanticName: windows::core::PCSTR(b"POSITION\0".as_ptr()),
            Format: DXGI_FORMAT_R32G32B32_FLOAT,
            AlignedByteOffset: 0,
            InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
            ..Default::default()
        },
        D3D12_INPUT_ELEMENT_DESC {
            SemanticName: windows::core::PCSTR(b"NORMAL\0".as_ptr()),
            Format: DXGI_FORMAT_R32G32B32_FLOAT,
            AlignedByteOffset: 12,
            InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
            ..Default::default()
        },
        D3D12_INPUT_ELEMENT_DESC {
            SemanticName: windows::core::PCSTR(b"TEXCOORD\0".as_ptr()),
            Format: DXGI_FORMAT_R32G32_FLOAT,
            AlignedByteOffset: 24,
            InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
            ..Default::default()
        },
    ];
    let blend = D3D12_BLEND_DESC {
        RenderTarget: [D3D12_RENDER_TARGET_BLEND_DESC {
            RenderTargetWriteMask: D3D12_COLOR_WRITE_ENABLE_ALL.0 as u8,
            ..Default::default()
        }; 8],
        ..Default::default()
    };
    let depth = if depth_enable {
        D3D12_DEPTH_STENCIL_DESC {
            DepthEnable: true.into(),
            DepthWriteMask: D3D12_DEPTH_WRITE_MASK_ALL,
            DepthFunc: D3D12_COMPARISON_FUNC_LESS,
            ..Default::default()
        }
    } else {
        D3D12_DEPTH_STENCIL_DESC {
            DepthEnable: false.into(),
            ..Default::default()
        }
    };
    let desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC {
        pRootSignature: ManuallyDrop::new(Some(root_sig.clone())),
        VS: D3D12_SHADER_BYTECODE {
            pShaderBytecode: vs.as_ptr() as *const _,
            BytecodeLength: vs.len(),
        },
        PS: D3D12_SHADER_BYTECODE {
            pShaderBytecode: ps.as_ptr() as *const _,
            BytecodeLength: ps.len(),
        },
        BlendState: blend,
        DepthStencilState: depth,
        SampleMask: u32::MAX,
        RasterizerState: D3D12_RASTERIZER_DESC {
            FillMode: D3D12_FILL_MODE_SOLID,
            CullMode: D3D12_CULL_MODE_BACK,
            FrontCounterClockwise: false.into(),
            DepthClipEnable: true.into(),
            ..Default::default()
        },
        InputLayout: D3D12_INPUT_LAYOUT_DESC {
            pInputElementDescs: input.as_ptr(),
            NumElements: input.len() as u32,
        },
        PrimitiveTopologyType: D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE,
        NumRenderTargets: 1,
        RTVFormats: [
            rtv_format,
            DXGI_FORMAT_UNKNOWN,
            DXGI_FORMAT_UNKNOWN,
            DXGI_FORMAT_UNKNOWN,
            DXGI_FORMAT_UNKNOWN,
            DXGI_FORMAT_UNKNOWN,
            DXGI_FORMAT_UNKNOWN,
            DXGI_FORMAT_UNKNOWN,
        ],
        DSVFormat: if depth_enable {
            DXGI_FORMAT_D32_FLOAT
        } else {
            DXGI_FORMAT_UNKNOWN
        },
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        ..Default::default()
    };
    device
        .CreateGraphicsPipelineState(&desc)
        .map_err(|e| e.to_string())
}

unsafe fn create_shadow_map(device: &ID3D12Device) -> Result<ID3D12Resource, String> {
    let heap = D3D12_HEAP_PROPERTIES {
        Type: D3D12_HEAP_TYPE_DEFAULT,
        ..Default::default()
    };
    let desc = D3D12_RESOURCE_DESC {
        Dimension: D3D12_RESOURCE_DIMENSION_TEXTURE2D,
        Width: SHADOW_SIZE as u64,
        Height: SHADOW_SIZE,
        DepthOrArraySize: 1,
        MipLevels: 1,
        Format: DXGI_FORMAT_R32_FLOAT,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        Flags: D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET,
        ..Default::default()
    };
    let clear = D3D12_CLEAR_VALUE {
        Format: DXGI_FORMAT_R32_FLOAT,
        Anonymous: D3D12_CLEAR_VALUE_0 {
            Color: [1.0, 1.0, 1.0, 1.0],
        },
    };
    let mut res: Option<ID3D12Resource> = None;
    device
        .CreateCommittedResource(
            &heap,
            D3D12_HEAP_FLAG_NONE,
            &desc,
            D3D12_RESOURCE_STATE_RENDER_TARGET,
            Some(&clear),
            &mut res,
        )
        .map_err(|e| e.to_string())?;
    res.ok_or_else(|| "shadow map".into())
}

fn tex_image_key(img: &Rgba8Image) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    let mut h = DefaultHasher::new();
    img.width.hash(&mut h);
    img.height.hash(&mut h);
    for b in img.pixels.iter().take(64) {
        b.hash(&mut h);
    }
    h.finish()
}

unsafe fn ensure_gpu_mesh<'a>(
    device: &ID3D12Device,
    pipe: &'a mut Forward3DPipeline,
    key: u64,
    mesh: &Mesh3d,
) -> Result<&'a CachedGpuMesh, String> {
    if !pipe.mesh_cache.contains_key(&key) {
        let mut m = mesh.clone();
        m.ensure_uvs();
        let vb = upload_mesh_vb(device, &m)?;
        let (ib, index_count) = upload_mesh_ib(device, &m.indices)?;
        pipe.mesh_cache.insert(
            key,
            CachedGpuMesh {
                vb,
                ib,
                index_count,
            },
        );
    }
    pipe.mesh_cache.get(&key).ok_or_else(|| "mesh cache".into())
}

unsafe fn cache_albedo_texture(
    device: &ID3D12Device,
    pipe: &mut Forward3DPipeline,
    draw: &Forward3DDraw,
) -> Result<(), String> {
    let queue = &pipe.queue;
    let allocator = &pipe.copy_allocator;
    let Some(img) = draw.albedo_image.as_ref() else {
        return Ok(());
    };
    let key = tex_image_key(img);
    if !pipe.texture_cache.contains_key(&key) {
        if pipe.next_srv_index >= SRV_HEAP_SIZE {
            return Err("SRV heap full".into());
        }
        let tex = create_texture_rgba8(device, queue, allocator, img)?;
        let mut cpu = pipe.srv_heap.GetCPUDescriptorHandleForHeapStart();
        cpu.ptr = cpu.ptr.wrapping_add(pipe.next_srv_index as usize * pipe.srv_stride as usize);
        create_srv_for_texture(device, &tex, cpu)?;
        let idx = pipe.next_srv_index;
        pipe.next_srv_index += 1;
        pipe.texture_cache.insert(
            key,
            CachedGpuTexture {
                texture: tex,
                srv_index: idx,
            },
        );
    }
    Ok(())
}

unsafe fn copy_albedo_to_slot(
    device: &ID3D12Device,
    pipe: &Forward3DPipeline,
    draw: &Forward3DDraw,
) -> Result<(), String> {
    let img = draw.albedo_image.as_ref().ok_or("no albedo")?;
    let key = tex_image_key(img);
    let cached = pipe.texture_cache.get(&key).ok_or("tex cache")?;
    let src = pipe.srv_heap.GetCPUDescriptorHandleForHeapStart();
    let src = D3D12_CPU_DESCRIPTOR_HANDLE {
        ptr: src.ptr.wrapping_add(cached.srv_index as usize * pipe.srv_stride as usize),
    };
    let mut dest = pipe.srv_heap.GetCPUDescriptorHandleForHeapStart();
    dest.ptr = dest.ptr.wrapping_add(SRV_DEFAULT_ALBEDO_INDEX as usize * pipe.srv_stride as usize);
    device.CopyDescriptorsSimple(1, dest, src, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    Ok(())
}

unsafe fn create_srv_for_texture(
    device: &ID3D12Device,
    texture: &ID3D12Resource,
    cpu: D3D12_CPU_DESCRIPTOR_HANDLE,
) -> Result<(), String> {
    device.CreateShaderResourceView(
        texture,
        Some(&D3D12_SHADER_RESOURCE_VIEW_DESC {
            Format: DXGI_FORMAT_R8G8B8A8_UNORM,
            ViewDimension: D3D12_SRV_DIMENSION_TEXTURE2D,
            Shader4ComponentMapping: D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
            Anonymous: D3D12_SHADER_RESOURCE_VIEW_DESC_0 {
                Texture2D: D3D12_TEX2D_SRV {
                    MipLevels: 1,
                    ..Default::default()
                },
            },
        }),
        cpu,
    );
    Ok(())
}

unsafe fn create_texture_rgba8(
    device: &ID3D12Device,
    queue: &ID3D12CommandQueue,
    allocator: &ID3D12CommandAllocator,
    img: &Rgba8Image,
) -> Result<ID3D12Resource, String> {
    use crate::pal::win_d3d12::transition;

    let w = img.width.max(1);
    let h = img.height.max(1);
    let row_pitch = ((w * 4 + 255) / 256) * 256;
    let upload_size = row_pitch as u64 * h as u64;
    let staging = create_upload_buffer(device, upload_size.max(256))?;
    let mut mapped: *mut c_void = ptr::null_mut();
    staging.Map(0, None, Some(&mut mapped)).map_err(|e| e.to_string())?;
    for y in 0..h as usize {
        for x in 0..w as usize {
            let si = (y * w as usize + x) * 4;
            let di = y * row_pitch as usize + x * 4;
            if si + 3 < img.pixels.len() {
                ptr::copy_nonoverlapping(
                    img.pixels[si..si + 4].as_ptr(),
                    (mapped as *mut u8).add(di),
                    4,
                );
            }
        }
    }
    staging.Unmap(0, None);

    let default_heap = D3D12_HEAP_PROPERTIES {
        Type: D3D12_HEAP_TYPE_DEFAULT,
        ..Default::default()
    };
    let desc = D3D12_RESOURCE_DESC {
        Dimension: D3D12_RESOURCE_DIMENSION_TEXTURE2D,
        Width: w as u64,
        Height: h,
        DepthOrArraySize: 1,
        MipLevels: 1,
        Format: DXGI_FORMAT_R8G8B8A8_UNORM,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        Flags: D3D12_RESOURCE_FLAG_NONE,
        ..Default::default()
    };
    let mut tex: Option<ID3D12Resource> = None;
    device
        .CreateCommittedResource(
            &default_heap,
            D3D12_HEAP_FLAG_NONE,
            &desc,
            D3D12_RESOURCE_STATE_COPY_DEST,
            None,
            &mut tex,
        )
        .map_err(|e| e.to_string())?;
    let tex = tex.ok_or("texture")?;

    let list: ID3D12GraphicsCommandList = device
        .CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocator, None)
        .map_err(|e| e.to_string())?;
    let footprint = D3D12_PLACED_SUBRESOURCE_FOOTPRINT {
        Offset: 0,
        Footprint: D3D12_SUBRESOURCE_FOOTPRINT {
            Format: DXGI_FORMAT_R8G8B8A8_UNORM,
            Width: w,
            Height: h,
            Depth: 1,
            RowPitch: row_pitch,
        },
    };
    let copy_loc = D3D12_TEXTURE_COPY_LOCATION {
        pResource: ManuallyDrop::new(Some(tex.clone())),
        Type: D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX,
        Anonymous: D3D12_TEXTURE_COPY_LOCATION_0 {
            SubresourceIndex: 0,
        },
    };
    let src_loc = D3D12_TEXTURE_COPY_LOCATION {
        pResource: ManuallyDrop::new(Some(staging)),
        Type: D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT,
        Anonymous: D3D12_TEXTURE_COPY_LOCATION_0 {
            PlacedFootprint: footprint,
        },
    };
    list.CopyTextureRegion(&copy_loc, 0, 0, 0, &src_loc, None);
    transition(
        &list,
        &tex,
        D3D12_RESOURCE_STATE_COPY_DEST,
        D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE,
    );
    list.Close().map_err(|e| e.to_string())?;
    let cmd: ID3D12CommandList = list.cast().map_err(|e| e.to_string())?;
    queue.ExecuteCommandLists(&[Some(cmd)]);
    let fence: ID3D12Fence = device
        .CreateFence(0, D3D12_FENCE_FLAGS::default())
        .map_err(|e| e.to_string())?;
    let event = CreateEventW(None, false, false, None).map_err(|e| e.to_string())?;
    queue.Signal(&fence, 1).map_err(|e| e.to_string())?;
    if fence.GetCompletedValue() < 1 {
        fence
            .SetEventOnCompletion(1, event)
            .map_err(|e| e.to_string())?;
        WaitForSingleObject(event, INFINITE);
    }
    allocator.Reset().map_err(|e| e.to_string())?;
    Ok(tex)
}

unsafe fn upload_mesh_vb(device: &ID3D12Device, mesh: &Mesh3d) -> Result<ID3D12Resource, String> {
    let mut verts = Vec::with_capacity(mesh.vertex_count());
    for i in 0..mesh.vertex_count() {
        verts.push(Vertex3d {
            pos: [
                mesh.positions[i * 3],
                mesh.positions[i * 3 + 1],
                mesh.positions[i * 3 + 2],
            ],
            normal: [
                mesh.normals[i * 3],
                mesh.normals[i * 3 + 1],
                mesh.normals[i * 3 + 2],
            ],
            uv: [
                mesh.uvs.get(i * 2).copied().unwrap_or(0.0),
                mesh.uvs.get(i * 2 + 1).copied().unwrap_or(0.0),
            ],
        });
    }
    let size = (verts.len() * std::mem::size_of::<Vertex3d>()) as u64;
    let vb = create_upload_buffer(device, size.max(256))?;
    let mut mapped: *mut c_void = ptr::null_mut();
    vb.Map(0, None, Some(&mut mapped)).map_err(|e| e.to_string())?;
    ptr::copy_nonoverlapping(
        verts.as_ptr() as *const u8,
        mapped as *mut u8,
        verts.len() * std::mem::size_of::<Vertex3d>(),
    );
    vb.Unmap(0, None);
    Ok(vb)
}

unsafe fn upload_mesh_ib(
    device: &ID3D12Device,
    indices: &[u32],
) -> Result<(ID3D12Resource, u32), String> {
    let size = (indices.len() * 4) as u64;
    let ib = create_default_buffer(device, size, indices.as_ptr() as *const u8)?;
    Ok((ib, indices.len() as u32))
}

unsafe fn create_default_buffer(
    device: &ID3D12Device,
    size: u64,
    data: *const u8,
) -> Result<ID3D12Resource, String> {
    let upload = create_upload_buffer(device, size)?;
    let mut mapped: *mut c_void = ptr::null_mut();
    upload.Map(0, None, Some(&mut mapped)).map_err(|e| e.to_string())?;
    ptr::copy_nonoverlapping(data, mapped as *mut u8, size as usize);
    upload.Unmap(0, None);

    let default_heap = D3D12_HEAP_PROPERTIES {
        Type: D3D12_HEAP_TYPE_DEFAULT,
        ..Default::default()
    };
    let desc = D3D12_RESOURCE_DESC {
        Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
        Width: size,
        Height: 1,
        DepthOrArraySize: 1,
        MipLevels: 1,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        Layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
        ..Default::default()
    };
    let mut res: Option<ID3D12Resource> = None;
    device
        .CreateCommittedResource(
            &default_heap,
            D3D12_HEAP_FLAG_NONE,
            &desc,
            D3D12_RESOURCE_STATE_COPY_DEST,
            None,
            &mut res,
        )
        .map_err(|e| e.to_string())?;
    let res = res.ok_or("default buffer")?;
    // M3: use upload VB directly (GENERIC_READ) — skip copy queue for demo simplicity
    drop(res);
    Ok(upload)
}

unsafe fn create_upload_buffer(device: &ID3D12Device, size: u64) -> Result<ID3D12Resource, String> {
    let heap = D3D12_HEAP_PROPERTIES {
        Type: D3D12_HEAP_TYPE_UPLOAD,
        ..Default::default()
    };
    let desc = D3D12_RESOURCE_DESC {
        Dimension: D3D12_RESOURCE_DIMENSION_BUFFER,
        Width: size,
        Height: 1,
        DepthOrArraySize: 1,
        MipLevels: 1,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        Layout: D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
        ..Default::default()
    };
    let mut res: Option<ID3D12Resource> = None;
    device
        .CreateCommittedResource(
            &heap,
            D3D12_HEAP_FLAG_NONE,
            &desc,
            D3D12_RESOURCE_STATE_GENERIC_READ,
            None,
            &mut res,
        )
        .map_err(|e| e.to_string())?;
    res.ok_or_else(|| "upload buffer".into())
}

unsafe fn create_depth_texture(
    device: &ID3D12Device,
    width: u32,
    height: u32,
) -> Result<ID3D12Resource, String> {
    let heap = D3D12_HEAP_PROPERTIES {
        Type: D3D12_HEAP_TYPE_DEFAULT,
        ..Default::default()
    };
    let desc = D3D12_RESOURCE_DESC {
        Dimension: D3D12_RESOURCE_DIMENSION_TEXTURE2D,
        Width: width.max(1) as u64,
        Height: height.max(1),
        DepthOrArraySize: 1,
        MipLevels: 1,
        Format: DXGI_FORMAT_D32_FLOAT,
        SampleDesc: DXGI_SAMPLE_DESC {
            Count: 1,
            Quality: 0,
        },
        Flags: D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL,
        ..Default::default()
    };
    let clear = D3D12_CLEAR_VALUE {
        Format: DXGI_FORMAT_D32_FLOAT,
        Anonymous: D3D12_CLEAR_VALUE_0 {
            DepthStencil: D3D12_DEPTH_STENCIL_VALUE {
                Depth: 1.0,
                Stencil: 0,
            },
        },
    };
    let mut res: Option<ID3D12Resource> = None;
    device
        .CreateCommittedResource(
            &heap,
            D3D12_HEAP_FLAG_NONE,
            &desc,
            D3D12_RESOURCE_STATE_DEPTH_WRITE,
            Some(&clear),
            &mut res,
        )
        .map_err(|e| e.to_string())?;
    res.ok_or_else(|| "depth".into())
}

/// Clear + forward 3D + present.
pub unsafe fn present_frame_with_forward3d(
    dx: &mut crate::pal::win_d3d12::Dx12State,
    clear: &Color,
    frame: &Forward3DFrame,
) -> Result<(), String> {
    use crate::pal::win_d3d12::{transition, wait_for_fence};

    let pipe = dx
        .forward3d
        .as_mut()
        .ok_or("forward3d pipeline not initialized")?;

    dx.frame_index = dx.swap_chain.GetCurrentBackBufferIndex();
    dx.allocator.Reset().map_err(|e| e.to_string())?;
    dx.list
        .Reset(&dx.allocator, None)
        .map_err(|e| e.to_string())?;

    let buf = dx.back_buffers[dx.frame_index as usize].clone();
    transition(
        &dx.list,
        &buf,
        D3D12_RESOURCE_STATE_PRESENT,
        D3D12_RESOURCE_STATE_RENDER_TARGET,
    );

    let mut rtv = dx.rtv_heap.GetCPUDescriptorHandleForHeapStart();
    rtv.ptr = rtv
        .ptr
        .wrapping_add(dx.frame_index as usize * dx.rtv_stride as usize);
    let dsv = pipe.dsv_heap.GetCPUDescriptorHandleForHeapStart();
    let clear_arr = [clear.r, clear.g, clear.b, clear.a];
    dx.list.ClearRenderTargetView(rtv, &clear_arr, None);

    draw_forward3d(
        &dx.list,
        &dx.device,
        pipe,
        rtv,
        dsv,
        (dx.width, dx.height),
        frame,
    )?;

    transition(
        &dx.list,
        &buf,
        D3D12_RESOURCE_STATE_RENDER_TARGET,
        D3D12_RESOURCE_STATE_PRESENT,
    );
    dx.list.Close().map_err(|e| e.to_string())?;
    let cmd: ID3D12CommandList = dx.list.cast().map_err(|e| e.to_string())?;
    dx.queue.ExecuteCommandLists(&[Some(cmd)]);
    dx.swap_chain
        .Present(1, windows::Win32::Graphics::Dxgi::DXGI_PRESENT(0))
        .ok()
        .map_err(|e| e.to_string())?;
    wait_for_fence(dx)?;
    Ok(())
}
