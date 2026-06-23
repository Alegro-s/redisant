//! M2: D3D12 draw path for [`SpriteBatch2D`](crate::render::SpriteBatch2D).

use std::mem::ManuallyDrop;
use std::ffi::c_void;
use std::ptr;

use windows::core::Interface;
use windows::Win32::Graphics::Direct3D::*;
use windows::Win32::Graphics::Direct3D12::*;
use windows::Win32::Graphics::Dxgi::Common::{
    DXGI_FORMAT, DXGI_FORMAT_R32G32_FLOAT, DXGI_FORMAT_R32G32B32A32_FLOAT, DXGI_FORMAT_UNKNOWN,
    DXGI_SAMPLE_DESC,
};

use crate::render::batch2d::{Batch2DVertex, SpriteBatch2D};

const VS_BYTECODE: &[u8] = include_bytes!("../../assets/shaders/batch2d_vs.cso");
const PS_BYTECODE: &[u8] = include_bytes!("../../assets/shaders/batch2d_ps.cso");

const MAX_VERTICES: usize = 4096 * 6;
const VB_BYTES: usize = MAX_VERTICES * std::mem::size_of::<Batch2DVertex>();

pub struct Batch2DPipeline {
    root_sig: ID3D12RootSignature,
    pso: ID3D12PipelineState,
    vb: ID3D12Resource,
}

pub unsafe fn init_batch2d_pipeline(
    device: &ID3D12Device,
    rtv_format: DXGI_FORMAT,
) -> Result<Batch2DPipeline, String> {
    let root_sig = create_root_signature(device)?;
    let pso = create_pso(device, &root_sig, rtv_format)?;
    let vb = create_upload_buffer(device, VB_BYTES as u64)?;
    Ok(Batch2DPipeline { root_sig, pso, vb })
}

pub unsafe fn draw_batch2d(
    list: &ID3D12GraphicsCommandList,
    pipeline: &Batch2DPipeline,
    rtv: D3D12_CPU_DESCRIPTOR_HANDLE,
    viewport: (u32, u32),
    batch: &mut SpriteBatch2D,
) -> Result<(), String> {
    batch.set_viewport(viewport.0 as f32, viewport.1 as f32);
    let vertices = batch.build_vertices();
    if vertices.is_empty() {
        return Ok(());
    }

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

    upload_vertices(&pipeline.vb, &vertices)?;

    list.OMSetRenderTargets(1, Some(&rtv), None, None);
    list.SetGraphicsRootSignature(&pipeline.root_sig);
    list.SetPipelineState(&pipeline.pso);

    let vb_view = D3D12_VERTEX_BUFFER_VIEW {
        BufferLocation: pipeline.vb.GetGPUVirtualAddress(),
        SizeInBytes: (vertices.len() * std::mem::size_of::<Batch2DVertex>()) as u32,
        StrideInBytes: std::mem::size_of::<Batch2DVertex>() as u32,
    };
    list.IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    list.IASetVertexBuffers(0, Some(&[vb_view]));
    list.DrawInstanced(vertices.len() as u32, 1, 0, 0);
    Ok(())
}

unsafe fn create_root_signature(device: &ID3D12Device) -> Result<ID3D12RootSignature, String> {
    let desc = D3D12_ROOT_SIGNATURE_DESC {
        Flags: D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT,
        ..Default::default()
    };
    let mut blob: Option<ID3DBlob> = None;
    let mut err: Option<ID3DBlob> = None;
    D3D12SerializeRootSignature(
        &desc,
        D3D_ROOT_SIGNATURE_VERSION_1,
        &mut blob,
        Some(&mut err),
    )
    .map_err(|e| format!("D3D12SerializeRootSignature: {e}"))?;
    let blob = blob.ok_or("root signature blob null")?;
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
    rtv_format: DXGI_FORMAT,
) -> Result<ID3D12PipelineState, String> {
    let input = [
        D3D12_INPUT_ELEMENT_DESC {
            SemanticName: windows::core::PCSTR(b"POSITION\0".as_ptr()),
            Format: DXGI_FORMAT_R32G32_FLOAT,
            AlignedByteOffset: 0,
            InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
            ..Default::default()
        },
        D3D12_INPUT_ELEMENT_DESC {
            SemanticName: windows::core::PCSTR(b"COLOR\0".as_ptr()),
            Format: DXGI_FORMAT_R32G32B32A32_FLOAT,
            AlignedByteOffset: 8,
            InputSlotClass: D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA,
            ..Default::default()
        },
    ];

    let blend = D3D12_BLEND_DESC {
        AlphaToCoverageEnable: false.into(),
        IndependentBlendEnable: false.into(),
        RenderTarget: [
            D3D12_RENDER_TARGET_BLEND_DESC {
                BlendEnable: true.into(),
                SrcBlend: D3D12_BLEND_SRC_ALPHA,
                DestBlend: D3D12_BLEND_INV_SRC_ALPHA,
                BlendOp: D3D12_BLEND_OP_ADD,
                SrcBlendAlpha: D3D12_BLEND_ONE,
                DestBlendAlpha: D3D12_BLEND_INV_SRC_ALPHA,
                BlendOpAlpha: D3D12_BLEND_OP_ADD,
                LogicOpEnable: false.into(),
                LogicOp: D3D12_LOGIC_OP_NOOP,
                RenderTargetWriteMask: D3D12_COLOR_WRITE_ENABLE_ALL.0 as u8,
            },
            Default::default(),
            Default::default(),
            Default::default(),
            Default::default(),
            Default::default(),
            Default::default(),
            Default::default(),
        ],
    };

    let desc = D3D12_GRAPHICS_PIPELINE_STATE_DESC {
        pRootSignature: ManuallyDrop::new(Some(root_sig.clone())),
        VS: D3D12_SHADER_BYTECODE {
            pShaderBytecode: VS_BYTECODE.as_ptr() as *const _,
            BytecodeLength: VS_BYTECODE.len(),
        },
        PS: D3D12_SHADER_BYTECODE {
            pShaderBytecode: PS_BYTECODE.as_ptr() as *const _,
            BytecodeLength: PS_BYTECODE.len(),
        },
        BlendState: blend,
        SampleMask: u32::MAX,
        RasterizerState: D3D12_RASTERIZER_DESC {
            FillMode: D3D12_FILL_MODE_SOLID,
            CullMode: D3D12_CULL_MODE_NONE,
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
    res.ok_or_else(|| "upload buffer null".into())
}

unsafe fn upload_vertices(vb: &ID3D12Resource, vertices: &[Batch2DVertex]) -> Result<(), String> {
    let mut mapped: *mut c_void = ptr::null_mut();
    vb.Map(0, None, Some(&mut mapped))
        .map_err(|e| e.to_string())?;
    ptr::copy_nonoverlapping(
        vertices.as_ptr() as *const u8,
        mapped as *mut u8,
        vertices.len() * std::mem::size_of::<Batch2DVertex>(),
    );
    vb.Unmap(0, None);
    Ok(())
}

/// Clear + optional 2D batch + present (M2 frame).
pub unsafe fn present_frame_with_batch(
    dx: &mut crate::pal::win_d3d12::Dx12State,
    clear: &crate::render::Color,
    batch: Option<&mut SpriteBatch2D>,
    viewport: (u32, u32),
) -> Result<(), String> {
    use crate::pal::win_d3d12::{transition, wait_for_fence};

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
    let clear_arr = [clear.r, clear.g, clear.b, clear.a];
    dx.list.ClearRenderTargetView(rtv, &clear_arr, None);

    if let (Some(batch), Some(pipe)) = (batch, dx.batch_pipeline.as_ref()) {
        draw_batch2d(&dx.list, pipe, rtv, viewport, batch)?;
    }

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
