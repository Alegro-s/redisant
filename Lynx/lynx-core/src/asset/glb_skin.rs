//! M13a: GLB skinning + animation clips (CPU path для Forward3D).

use crate::asset::glb_minimal::load_glb;
use crate::math::{Mat4, Vec3};
use crate::render::mesh3d::{compute_normals, Mesh3d};

/// Скининг + клипы из одного GLB.
#[derive(Clone, Debug)]
pub struct SkinnedGlb {
    pub bind: Mesh3d,
    pub joints: SkinJoints,
    pub clips: Vec<GltfAnimClip>,
}

#[derive(Clone, Debug)]
pub struct SkinJoints {
    pub inverse_bind: Vec<Mat4>,
    /// glTF node index per joint slot.
    pub node_indices: Vec<usize>,
    pub vertex_joints: Vec<[u16; 4]>,
    pub vertex_weights: Vec<[f32; 4]>,
    pub rest_locals: Vec<NodeTrs>,
    pub node_parents: Vec<Option<usize>>,
}

#[derive(Clone, Debug)]
pub struct NodeTrs {
    pub translation: Vec3,
    pub rotation: [f32; 4],
    pub scale: Vec3,
}

#[derive(Clone, Debug)]
pub struct GltfAnimClip {
    pub name: String,
    pub duration: f32,
    pub channels: Vec<AnimChannel>,
}

#[derive(Clone, Debug)]
pub enum AnimPath {
    Translation,
    Rotation,
}

#[derive(Clone, Debug)]
pub struct AnimChannel {
    pub node: usize,
    pub path: AnimPath,
    pub times: Vec<f32>,
    pub translations: Vec<Vec3>,
    pub rotations: Vec<[f32; 4]>,
}

pub fn load_glb_skinned(bytes: &[u8]) -> Option<SkinnedGlb> {
    let (json, bin) = parse_glb_root(bytes)?;
    let skinned = parse_skinned_mesh(&json, bin)?;
    let clips = parse_animations(&json, bin);
    Some(SkinnedGlb {
        bind: skinned.0,
        joints: skinned.1,
        clips,
    })
}

impl SkinnedGlb {
    pub fn has_skinning(&self) -> bool {
        !self.joints.node_indices.is_empty()
    }

    pub fn mesh_at(&self, clip: Option<&GltfAnimClip>, time: f32) -> Mesh3d {
        if !self.has_skinning() {
            return self.bind.clone();
        }
        let globals = self.joints.global_matrices(clip, time);
        skin_mesh(&self.bind, &self.joints, &globals)
    }

    pub fn clip_by_name<'a>(&'a self, name: &str) -> Option<&'a GltfAnimClip> {
        self.clips.iter().find(|c| c.name == name).or(self.clips.first())
    }
}

impl SkinJoints {
    pub fn global_matrices(&self, clip: Option<&GltfAnimClip>, time: f32) -> Vec<Mat4> {
        let mut locals: Vec<NodeTrs> = self.rest_locals.clone();
        if let Some(clip) = clip {
            for ch in &clip.channels {
                if ch.node >= locals.len() {
                    continue;
                }
                match ch.path {
                    AnimPath::Translation => {
                        if let Some(t) = sample_translation(ch, time) {
                            locals[ch.node].translation = t;
                        }
                    }
                    AnimPath::Rotation => {
                        if let Some(r) = sample_rotation(ch, time) {
                            locals[ch.node].rotation = r;
                        }
                    }
                }
            }
        }
        let n = locals.len().max(self.node_indices.iter().copied().max().unwrap_or(0) + 1);
        let mut globals = vec![Mat4::identity(); n];
        for _ in 0..n {
            for i in 0..n {
                let local = trs_to_mat(&locals[i]);
                if let Some(p) = self.node_parents.get(i).and_then(|x| *x) {
                    if p < n {
                        globals[i] = globals[p].multiply(local);
                    } else {
                        globals[i] = local;
                    }
                } else {
                    globals[i] = local;
                }
            }
        }
        globals
    }
}

fn trs_to_mat(trs: &NodeTrs) -> Mat4 {
    let t = Mat4::translation(trs.translation);
    let r = Mat4::from_quat(trs.rotation);
    let s = Mat4::scale_vec(trs.scale);
    t.multiply(r).multiply(s)
}

fn sample_translation(ch: &AnimChannel, time: f32) -> Option<Vec3> {
    if ch.translations.is_empty() || ch.times.is_empty() {
        return None;
    }
    let i = find_key_index(&ch.times, time);
    let next = (i + 1).min(ch.translations.len() - 1);
    let t0 = ch.times[i];
    let t1 = ch.times[next];
    let f = if (t1 - t0).abs() < 1e-6 {
        0.0
    } else {
        ((time - t0) / (t1 - t0)).clamp(0.0, 1.0)
    };
    let va = ch.translations[i];
    let vb = ch.translations[next];
    Some(Vec3::new(
        va.x + (vb.x - va.x) * f,
        va.y + (vb.y - va.y) * f,
        va.z + (vb.z - va.z) * f,
    ))
}

fn sample_rotation(ch: &AnimChannel, time: f32) -> Option<[f32; 4]> {
    if ch.rotations.is_empty() || ch.times.is_empty() {
        return None;
    }
    let i = find_key_index(&ch.times, time);
    let next = (i + 1).min(ch.rotations.len() - 1);
    let t0 = ch.times[i];
    let t1 = ch.times[next];
    let f = if (t1 - t0).abs() < 1e-6 {
        0.0
    } else {
        ((time - t0) / (t1 - t0)).clamp(0.0, 1.0)
    };
    let a = ch.rotations[i];
    let b = ch.rotations[next];
    Some([
        a[0] + (b[0] - a[0]) * f,
        a[1] + (b[1] - a[1]) * f,
        a[2] + (b[2] - a[2]) * f,
        a[3] + (b[3] - a[3]) * f,
    ])
}

fn find_key_index(times: &[f32], time: f32) -> usize {
    let mut i = 0usize;
    for (idx, &t) in times.iter().enumerate() {
        if t <= time {
            i = idx;
        } else {
            break;
        }
    }
    i
}

pub fn skin_mesh(bind: &Mesh3d, skin: &SkinJoints, joint_globals: &[Mat4]) -> Mesh3d {
    let n = bind.vertex_count();
    let mut positions = vec![0.0f32; n * 3];
    for v in 0..n {
        let bp = Vec3::new(
            bind.positions[v * 3],
            bind.positions[v * 3 + 1],
            bind.positions[v * 3 + 2],
        );
        let mut acc = Vec3::new(0.0, 0.0, 0.0);
        let w = skin.vertex_weights[v];
        let j = skin.vertex_joints[v];
        for slot in 0..4 {
            let weight = w[slot];
            if weight < 1e-5 {
                continue;
            }
            let joint_i = j[slot] as usize;
            if joint_i >= skin.inverse_bind.len() {
                continue;
            }
            let palette = if joint_i < skin.node_indices.len() {
                let node = skin.node_indices[joint_i];
                if node < joint_globals.len() {
                    joint_globals[node].multiply(skin.inverse_bind[joint_i])
                } else {
                    skin.inverse_bind[joint_i]
                }
            } else {
                skin.inverse_bind[joint_i]
            };
            let tp = palette.transform_point(bp);
            acc.x += tp.x * weight;
            acc.y += tp.y * weight;
            acc.z += tp.z * weight;
        }
        positions[v * 3] = acc.x;
        positions[v * 3 + 1] = acc.y;
        positions[v * 3 + 2] = acc.z;
    }
    let normals = compute_normals(&positions, &bind.indices);
    Mesh3d {
        positions,
        normals,
        uvs: bind.uvs.clone(),
        indices: bind.indices.clone(),
    }
}

fn parse_glb_root(bytes: &[u8]) -> Option<(serde_json::Value, Option<&[u8]>)> {
    if bytes.len() < 20 || &bytes[0..4] != b"glTF" {
        return None;
    }
    let json_len = u32::from_le_bytes(bytes[12..16].try_into().ok()?) as usize;
    if 20 + json_len > bytes.len() {
        return None;
    }
    let json: serde_json::Value = serde_json::from_slice(&bytes[20..20 + json_len]).ok()?;
    let mut bin = None;
    let mut off = 20 + json_len;
    if off + 8 <= bytes.len() {
        let bin_len = u32::from_le_bytes(bytes[off..off + 4].try_into().ok()?) as usize;
        off += 8;
        if off + bin_len <= bytes.len() {
            bin = Some(&bytes[off..off + bin_len]);
        }
    }
    Some((json, bin))
}

fn parse_skinned_mesh(
    root: &serde_json::Value,
    bin: Option<&[u8]>,
) -> Option<(Mesh3d, SkinJoints)> {
    let bind = parse_mesh_from_root(root, bin)?;
    let accessors = root.get("accessors")?.as_array()?;
    let views = root.get("bufferViews")?.as_array()?;
    let buffers = root.get("buffers")?.as_array()?;
    let meshes = root.get("meshes")?.as_array()?;
    let prim = meshes.first()?.get("primitives")?.as_array()?.first()?;
    let attrs = prim.get("attributes")?.as_object()?;
    let joints_attr = attrs.get("JOINTS_0")?.as_u64()? as usize;
    let weights_attr = attrs.get("WEIGHTS_0")?.as_u64()? as usize;
    let joint_count = attrs
        .get("JOINTS_0")
        .and_then(|_| read_joints_vec4(joints_attr, accessors, views, buffers, bin))
        .map(|v| v.len())
        .unwrap_or(0);
    if joint_count == 0 {
        return None;
    }
    let vertex_joints = read_joints_vec4(joints_attr, accessors, views, buffers, bin)?;
    let vertex_weights = read_weights_vec4(weights_attr, accessors, views, buffers, bin)?;
    let skin_idx = prim.get("skin")?.as_u64()? as usize;
    let skins = root.get("skins")?.as_array()?;
    let skin = skins.get(skin_idx)?.as_object()?;
    let joint_nodes: Vec<usize> = skin
        .get("joints")?
        .as_array()?
        .iter()
        .filter_map(|v| v.as_u64().map(|x| x as usize))
        .collect();
    let ibm_acc = skin.get("inverseBindMatrices")?.as_u64()? as usize;
    let inverse_bind = read_mat4_accessor(ibm_acc, accessors, views, buffers, bin)?;
    let node_count = root
        .get("nodes")
        .and_then(|n| n.as_array())
        .map(|a| a.len())
        .unwrap_or(joint_nodes.iter().copied().max().unwrap_or(0) + 1);
    let rest_locals = parse_node_rest(root, node_count);
    let node_parents = build_node_parents(root, node_count);
    Some((
        bind,
        SkinJoints {
            inverse_bind,
            node_indices: joint_nodes,
            vertex_joints,
            vertex_weights,
            rest_locals,
            node_parents,
        },
    ))
}

fn build_node_parents(root: &serde_json::Value, count: usize) -> Vec<Option<usize>> {
    let mut parents = vec![None; count];
    let Some(nodes) = root.get("nodes").and_then(|n| n.as_array()) else {
        return parents;
    };
    for (i, node) in nodes.iter().enumerate() {
        let Some(children) = node.get("children").and_then(|c| c.as_array()) else {
            continue;
        };
        for c in children {
            if let Some(child) = c.as_u64() {
                let ci = child as usize;
                if ci < count {
                    parents[ci] = Some(i);
                }
            }
        }
    }
    parents
}

fn parse_mesh_from_root(root: &serde_json::Value, bin: Option<&[u8]>) -> Option<Mesh3d> {
    let json_bytes = serde_json::to_vec(root).ok()?;
    let mut fake = Vec::new();
    fake.extend_from_slice(b"glTF");
    fake.extend_from_slice(&2u32.to_le_bytes());
    fake.extend_from_slice(&(json_bytes.len() as u32).to_le_bytes());
    fake.extend_from_slice(&json_bytes);
    if let Some(b) = bin {
        fake.extend_from_slice(&(b.len() as u32).to_le_bytes());
        fake.extend_from_slice(&b.len().to_le_bytes());
        fake.extend_from_slice(b);
    }
    load_glb(&fake)
}

fn parse_node_rest(root: &serde_json::Value, count: usize) -> Vec<NodeTrs> {
    let mut out = vec![
        NodeTrs {
            translation: Vec3::new(0.0, 0.0, 0.0),
            rotation: [0.0, 0.0, 0.0, 1.0],
            scale: Vec3::new(1.0, 1.0, 1.0),
        };
        count
    ];
    let Some(nodes) = root.get("nodes").and_then(|n| n.as_array()) else {
        return out;
    };
    for (i, node) in nodes.iter().enumerate().take(count) {
        let o = node.as_object();
        if o.is_none() {
            continue;
        }
        let o = o.unwrap();
        let t = o
            .get("translation")
            .and_then(|v| v.as_array())
            .map(|a| vec3_from_arr(a))
            .unwrap_or(Vec3::new(0.0, 0.0, 0.0));
        let r = o
            .get("rotation")
            .and_then(|v| v.as_array())
            .map(|a| quat_from_arr(a))
            .unwrap_or([0.0, 0.0, 0.0, 1.0]);
        let s = o
            .get("scale")
            .and_then(|v| v.as_array())
            .map(|a| vec3_from_arr(a))
            .unwrap_or(Vec3::new(1.0, 1.0, 1.0));
        out[i] = NodeTrs {
            translation: t,
            rotation: r,
            scale: s,
        };
    }
    out
}

fn vec3_from_arr(a: &[serde_json::Value]) -> Vec3 {
    Vec3::new(
        a.first().and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
        a.get(1).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
        a.get(2).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
    )
}

fn quat_from_arr(a: &[serde_json::Value]) -> [f32; 4] {
    [
        a.first().and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
        a.get(1).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
        a.get(2).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
        a.get(3).and_then(|v| v.as_f64()).unwrap_or(1.0) as f32,
    ]
}

fn parse_animations(root: &serde_json::Value, bin: Option<&[u8]>) -> Vec<GltfAnimClip> {
    let Some(anims) = root.get("animations").and_then(|a| a.as_array()) else {
        return Vec::new();
    };
    let accessors = match root.get("accessors").and_then(|a| a.as_array()) {
        Some(a) => a,
        None => return Vec::new(),
    };
    let views = match root.get("bufferViews").and_then(|a| a.as_array()) {
        Some(a) => a,
        None => return Vec::new(),
    };
    let buffers = match root.get("buffers").and_then(|a| a.as_array()) {
        Some(a) => a,
        None => return Vec::new(),
    };
    let mut out = Vec::new();
    for (ai, anim) in anims.iter().enumerate() {
        let o = match anim.as_object() {
            Some(o) => o,
            None => continue,
        };
        let name = o
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("anim")
            .to_string();
        let mut channels = Vec::new();
        let mut duration = 0.0f32;
        if let Some(chs) = o.get("channels").and_then(|c| c.as_array()) {
            for ch in chs {
                let co = match ch.as_object() {
                    Some(x) => x,
                    None => continue,
                };
                let Some(target) = co.get("target").and_then(|v| v.as_object()) else {
                    continue;
                };
                let Some(node) = target.get("node").and_then(|v| v.as_u64()) else {
                    continue;
                };
                let node = node as usize;
                let path = match target.get("path").and_then(|v| v.as_str()) {
                    Some("translation") => AnimPath::Translation,
                    Some("rotation") => AnimPath::Rotation,
                    _ => continue,
                };
                let Some(sampler_idx) = co.get("sampler").and_then(|v| v.as_u64()) else {
                    continue;
                };
                let Some(samplers) = o.get("samplers").and_then(|v| v.as_array()) else {
                    continue;
                };
                let Some(sampler) = samplers
                    .get(sampler_idx as usize)
                    .and_then(|v| v.as_object())
                else {
                    continue;
                };
                let Some(input) = sampler.get("input").and_then(|v| v.as_u64()) else {
                    continue;
                };
                let Some(output) = sampler.get("output").and_then(|v| v.as_u64()) else {
                    continue;
                };
                let input = input as usize;
                let output = output as usize;
                let times = read_f32_accessor(input, 1, accessors, views, buffers, bin).unwrap_or_default();
                if let Some(&t) = times.last() {
                    duration = duration.max(t);
                }
                let (translations, rotations) = match path {
                    AnimPath::Translation => (
                        read_vec3_accessor(output, accessors, views, buffers, bin),
                        Vec::new(),
                    ),
                    AnimPath::Rotation => (
                        Vec::new(),
                        read_quat_accessor(output, accessors, views, buffers, bin),
                    ),
                };
                channels.push(AnimChannel {
                    node,
                    path,
                    times,
                    translations,
                    rotations,
                });
            }
        }
        out.push(GltfAnimClip {
            name: if name == "anim" {
                format!("anim_{ai}")
            } else {
                name
            },
            duration: duration.max(0.001),
            channels,
        });
    }
    out
}

fn read_f32_accessor(
    acc_idx: usize,
    components: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    _buffers: &[serde_json::Value],
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
    let bytes = buffer_bytes(buf_idx, bin)?;
    let mut out = vec![0.0f32; count * components];
    for i in 0..count {
        let mut o = byte_off + i * stride;
        for c in 0..components {
            if o + 4 > bytes.len() {
                return None;
            }
            out[i * components + c] = f32::from_le_bytes(bytes[o..o + 4].try_into().ok()?);
            o += 4;
        }
    }
    Some(out)
}

fn read_joints_vec4(
    acc_idx: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    _buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Option<Vec<[u16; 4]>> {
    let acc = accessors.get(acc_idx)?.as_object()?;
    let count = acc.get("count")?.as_u64()? as usize;
    let ctype = acc.get("componentType")?.as_u64()? as u32;
    let view_idx = acc.get("bufferView")?.as_u64()? as usize;
    let view = views.get(view_idx)?.as_object()?;
    let buf_idx = view.get("buffer")?.as_u64()? as usize;
    let byte_off = view.get("byteOffset").and_then(|v| v.as_u64()).unwrap_or(0) as usize
        + acc.get("byteOffset").and_then(|v| v.as_u64()).unwrap_or(0) as usize;
    let bytes = buffer_bytes(buf_idx, bin)?;
    let mut out = Vec::with_capacity(count);
    for i in 0..count {
        let mut joints = [0u16; 4];
        for j in 0..4 {
            let v = match ctype {
                5121 => bytes.get(byte_off + i * 4 + j).copied()? as u16,
                5123 => {
                    let o = byte_off + i * 8 + j * 2;
                    u16::from_le_bytes(bytes[o..o + 2].try_into().ok()?) as u16
                }
                _ => return None,
            };
            joints[j] = v;
        }
        out.push(joints);
    }
    Some(out)
}

fn read_weights_vec4(
    acc_idx: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Option<Vec<[f32; 4]>> {
    let raw = read_f32_accessor(acc_idx, 4, accessors, views, buffers, bin)?;
    let n = raw.len() / 4;
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let mut w = [
            raw[i * 4],
            raw[i * 4 + 1],
            raw[i * 4 + 2],
            raw[i * 4 + 3],
        ];
        let sum: f32 = w.iter().sum();
        if sum > 1e-6 {
            for x in &mut w {
                *x /= sum;
            }
        }
        out.push(w);
    }
    Some(out)
}

fn read_mat4_accessor(
    acc_idx: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Option<Vec<Mat4>> {
    let raw = read_f32_accessor(acc_idx, 16, accessors, views, buffers, bin)?;
    let n = raw.len() / 16;
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let mut m = [0.0f32; 16];
        m.copy_from_slice(&raw[i * 16..i * 16 + 16]);
        out.push(Mat4 { m });
    }
    Some(out)
}

fn read_vec3_accessor(
    acc_idx: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Vec<Vec3> {
    read_f32_accessor(acc_idx, 3, accessors, views, buffers, bin)
        .unwrap_or_default()
        .chunks(3)
        .map(|c| Vec3::new(c[0], c[1], c[2]))
        .collect()
}

fn read_quat_accessor(
    acc_idx: usize,
    accessors: &[serde_json::Value],
    views: &[serde_json::Value],
    buffers: &[serde_json::Value],
    bin: Option<&[u8]>,
) -> Vec<[f32; 4]> {
    read_f32_accessor(acc_idx, 4, accessors, views, buffers, bin)
        .unwrap_or_default()
        .chunks(4)
        .map(|c| [c[0], c[1], c[2], c[3]])
        .collect()
}

fn buffer_bytes<'a>(buf_idx: usize, bin: Option<&'a [u8]>) -> Option<&'a [u8]> {
    if buf_idx == 0 {
        bin
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::render::mesh3d::Mesh3d;

    #[test]
    fn skin_mesh_single_joint_translation() {
        let bind = Mesh3d {
            positions: vec![0.0, 0.0, 0.0, 1.0, 0.0, 0.0],
            normals: vec![0.0, 1.0, 0.0, 0.0, 1.0, 0.0],
            uvs: vec![0.0, 0.0, 1.0, 0.0],
            indices: vec![0, 1],
        };
        let skin = SkinJoints {
            inverse_bind: vec![Mat4::identity()],
            node_indices: vec![0],
            vertex_joints: vec![[0, 0, 0, 0], [0, 0, 0, 0]],
            vertex_weights: vec![[1.0, 0.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0]],
            rest_locals: vec![NodeTrs {
                translation: Vec3::new(0.0, 0.0, 0.0),
                rotation: [0.0, 0.0, 0.0, 1.0],
                scale: Vec3::new(1.0, 1.0, 1.0),
            }],
            node_parents: vec![None],
        };
        let mut globals = vec![Mat4::identity()];
        globals[0] = Mat4::translation(Vec3::new(0.0, 2.0, 0.0));
        let out = skin_mesh(&bind, &skin, &globals);
        assert!((out.positions[1] - 2.0).abs() < 1e-4);
        assert!((out.positions[3] - 1.0).abs() < 1e-4);
        assert!((out.positions[4] - 2.0).abs() < 1e-4);
    }

    #[test]
    fn global_matrices_parent_chain() {
        let joints = SkinJoints {
            inverse_bind: vec![],
            node_indices: vec![],
            vertex_joints: vec![],
            vertex_weights: vec![],
            rest_locals: vec![
                NodeTrs {
                    translation: Vec3::new(1.0, 0.0, 0.0),
                    rotation: [0.0, 0.0, 0.0, 1.0],
                    scale: Vec3::new(1.0, 1.0, 1.0),
                },
                NodeTrs {
                    translation: Vec3::new(0.0, 1.0, 0.0),
                    rotation: [0.0, 0.0, 0.0, 1.0],
                    scale: Vec3::new(1.0, 1.0, 1.0),
                },
            ],
            node_parents: vec![None, Some(0)],
        };
        let globals = joints.global_matrices(None, 0.0);
        let child_origin = globals[1].transform_point(Vec3::new(0.0, 0.0, 0.0));
        assert!((child_origin.x - 1.0).abs() < 1e-4);
        assert!((child_origin.y - 1.0).abs() < 1e-4);
    }
}
