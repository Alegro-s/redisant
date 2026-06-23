//! Минимальный GLB (POSITION + indices) — только для загрузки мешей в Core M3.

use crate::render::mesh3d::{compute_normals, Mesh3d};

pub fn load_glb(bytes: &[u8]) -> Option<Mesh3d> {
    if bytes.len() < 20 {
        return None;
    }
    if &bytes[0..4] != b"glTF" {
        return None;
    }
    let json_len = u32::from_le_bytes(bytes[12..16].try_into().ok()?) as usize;
    if 20 + json_len > bytes.len() {
        return None;
    }
    let json: serde_json::Value =
        serde_json::from_slice(&bytes[20..20 + json_len]).ok()?;
    let mut bin: Option<&[u8]> = None;
    let mut off = 20 + json_len;
    if off + 8 <= bytes.len() {
        let bin_len = u32::from_le_bytes(bytes[off..off + 4].try_into().ok()?) as usize;
        off += 8;
        if off + bin_len <= bytes.len() {
            bin = Some(&bytes[off..off + bin_len]);
        }
    }
    parse_gltf_json(&json, bin)
}

fn parse_gltf_json(root: &serde_json::Value, bin: Option<&[u8]>) -> Option<Mesh3d> {
    let meshes = root.get("meshes")?.as_array()?;
    let mesh0 = meshes.first()?.as_object()?;
    let prims = mesh0.get("primitives")?.as_array()?;
    let prim = prims.first()?.as_object()?;
    let attrs = prim.get("attributes")?.as_object()?;
    let pos_idx = attrs.get("POSITION")?.as_u64()? as usize;
    let accessors = root.get("accessors")?.as_array()?;
    let views = root.get("bufferViews")?.as_array()?;
    let buffers = root.get("buffers")?.as_array()?;

    let positions = read_f32_accessor(pos_idx, 3, accessors, views, buffers, bin)?;
    let indices = if let Some(idx_acc) = prim.get("indices").and_then(|v| v.as_u64()) {
        read_indices(idx_acc as usize, accessors, views, buffers, bin)
            .unwrap_or_else(|| sequential_indices(positions.len() / 3))
    } else {
        sequential_indices(positions.len() / 3)
    };
    let normals = if let Some(ni) = attrs.get("NORMAL").and_then(|v| v.as_u64()) {
        read_f32_accessor(ni as usize, 3, accessors, views, buffers, bin)
            .unwrap_or_else(|| compute_normals(&positions, &indices))
    } else {
        compute_normals(&positions, &indices)
    };
    let uvs = attrs
        .get("TEXCOORD_0")
        .and_then(|v| v.as_u64())
        .and_then(|ni| read_f32_accessor(ni as usize, 2, accessors, views, buffers, bin))
        .unwrap_or_default();
    let mut mesh = Mesh3d {
        positions,
        normals,
        uvs,
        indices,
    };
    mesh.ensure_uvs();
    Some(mesh)
}

fn sequential_indices(verts: usize) -> Vec<u32> {
    (0..verts as u32).collect()
}

fn read_f32_accessor(
    acc_idx: usize,
    components: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Option<Vec<f32>> {
    let acc = accessors.get(acc_idx)?.as_object()?;
    let view_idx = acc.get("bufferView")?.as_u64()? as usize;
    let view = views.get(view_idx)?.as_object()?;
    let buf_idx = view.get("buffer")?.as_u64()? as usize;
    let byte_off = view.get("byteOffset").and_then(|v| v.as_u64()).unwrap_or(0) as usize
        + acc.get("byteOffset").and_then(|v| v.as_u64()).unwrap_or(0) as usize;
    let stride = view
        .get("byteStride")
        .and_then(|v| v.as_u64())
        .unwrap_or((components * 4) as u64) as usize;
    let count = acc.get("count")?.as_u64()? as usize;
    let bytes = buffer_bytes(buf_idx, buffers, bin)?;
    let mut out = vec![0.0f32; count * components];
    let mut o = byte_off;
    for i in 0..count {
        for c in 0..components {
            if o + 4 > bytes.len() {
                return None;
            }
            out[i * components + c] = f32::from_le_bytes(bytes[o..o + 4].try_into().ok()?);
            o += 4;
        }
        o = byte_off + (i + 1) * stride;
    }
    Some(out)
}

fn read_indices(
    acc_idx: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Option<Vec<u32>> {
    let acc = accessors.get(acc_idx)?.as_object()?;
    let view_idx = acc.get("bufferView")?.as_u64()? as usize;
    let view = views.get(view_idx)?.as_object()?;
    let buf_idx = view.get("buffer")?.as_u64()? as usize;
    let byte_off = view.get("byteOffset").and_then(|v| v.as_u64()).unwrap_or(0) as usize
        + acc.get("byteOffset").and_then(|v| v.as_u64()).unwrap_or(0) as usize;
    let count = acc.get("count")?.as_u64()? as usize;
    let comp = acc.get("componentType")?.as_u64()? as u32;
    let bytes = buffer_bytes(buf_idx, buffers, bin)?;
    let mut out = Vec::with_capacity(count);
    let mut o = byte_off;
    for _ in 0..count {
        let v = match comp {
            5121 => {
                if o + 1 > bytes.len() {
                    return None;
                }
                let x = bytes[o] as u32;
                o += 1;
                x
            }
            5123 => {
                if o + 2 > bytes.len() {
                    return None;
                }
                let x = u16::from_le_bytes(bytes[o..o + 2].try_into().ok()?) as u32;
                o += 2;
                x
            }
            5125 => {
                if o + 4 > bytes.len() {
                    return None;
                }
                let x = u32::from_le_bytes(bytes[o..o + 4].try_into().ok()?);
                o += 4;
                x
            }
            _ => return None,
        };
        out.push(v);
    }
    Some(out)
}

fn buffer_bytes<'a>(
    buf_idx: usize,
    _buffers: &'a [serde_json::Value],
    bin: Option<&'a [u8]>,
) -> Option<&'a [u8]> {
    if buf_idx == 0 {
        bin
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_non_gltf() {
        assert!(load_glb(b"not glb").is_none());
    }

    #[test]
    fn rejects_truncated_glb() {
        let mut glb = Vec::new();
        glb.extend_from_slice(b"glTF");
        glb.extend_from_slice(&2u32.to_le_bytes());
        glb.extend_from_slice(&32u32.to_le_bytes());
        glb.extend_from_slice(&8u32.to_le_bytes());
        glb.extend_from_slice(&0x4E4F534Au32.to_le_bytes());
        glb.extend_from_slice(b"{\"x\":1}");
        assert!(load_glb(&glb).is_none());
    }
}
