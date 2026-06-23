//! M13b: heightmap terrain mesh + distance LOD (CPU, Forward3D).

use crate::asset::texture_rgba8::Rgba8Image;
use crate::math::Vec3;
use crate::render::mesh3d::{compute_normals, Mesh3d};

/// Нормализованные высоты [0, 1], row-major `heights[z * hm_w + x]`.
pub fn heights_from_rgba8(img: &Rgba8Image) -> (Vec<f32>, u32, u32) {
    let w = img.width.max(1);
    let h = img.height.max(1);
    let mut out = Vec::with_capacity((w * h) as usize);
    for py in 0..h {
        for px in 0..w {
            let i = ((py * w + px) * 4) as usize;
            let r = img.pixels.get(i).copied().unwrap_or(0) as f32 / 255.0;
            out.push(r);
        }
    }
    (out, w, h)
}

pub fn sample_height_bilinear(heights: &[f32], hm_w: u32, hm_h: u32, u: f32, v: f32) -> f32 {
    let w = hm_w.max(1) as f32;
    let h = hm_h.max(1) as f32;
    let u = u.clamp(0.0, 1.0);
    let v = v.clamp(0.0, 1.0);
    let fx = u * (w - 1.0);
    let fz = v * (h - 1.0);
    let x0 = fx.floor() as u32;
    let z0 = fz.floor() as u32;
    let x1 = (x0 + 1).min(hm_w.saturating_sub(1));
    let z1 = (z0 + 1).min(hm_h.saturating_sub(1));
    let tx = fx - x0 as f32;
    let tz = fz - z0 as f32;
    let h00 = heights[(z0 * hm_w + x0) as usize];
    let h10 = heights[(z0 * hm_w + x1) as usize];
    let h01 = heights[(z1 * hm_w + x0) as usize];
    let h11 = heights[(z1 * hm_w + x1) as usize];
    let hx0 = h00 + (h10 - h00) * tx;
    let hx1 = h01 + (h11 - h01) * tx;
    hx0 + (hx1 - hx0) * tz
}

/// LOD 0 = full `base_segments`; каждый уровень делит сетку пополам (min 2).
pub fn lod_segment_count(base_segments: u32, lod: u32) -> u32 {
    let shift = lod.min(6);
    (base_segments >> shift).max(2)
}

/// Дистанция камеры → LOD (0 = ближайший).
pub fn select_terrain_lod(distance: f32, split_distance: f32, max_lod: u32) -> u32 {
    if split_distance <= 1e-4 {
        return 0;
    }
    let lod = (distance / split_distance).floor() as u32;
    lod.min(max_lod)
}

/// Сетка в XZ вокруг (0,0,0); `size` = [width, max_height, depth].
pub fn build_terrain_mesh(
    heights: &[f32],
    hm_w: u32,
    hm_h: u32,
    size: [f32; 3],
    segments_x: u32,
    segments_z: u32,
) -> Mesh3d {
    let sx = segments_x.max(2);
    let sz = segments_z.max(2);
    let max_h = size[1].max(0.001);

    let verts_x = (sx + 1) as usize;
    let verts_z = (sz + 1) as usize;
    let mut positions = Vec::with_capacity(verts_x * verts_z * 3);
    let mut uvs = Vec::with_capacity(verts_x * verts_z * 2);

    for iz in 0..=sz as usize {
        let v = iz as f32 / sz as f32;
        for ix in 0..=sx as usize {
            let u = ix as f32 / sx as f32;
            let h = sample_height_bilinear(heights, hm_w, hm_h, u, v);
            let x = (u - 0.5) * size[0];
            let z = (v - 0.5) * size[2];
            let y = h * max_h - max_h * 0.5;
            positions.push(x);
            positions.push(y);
            positions.push(z);
            uvs.push(u);
            uvs.push(v);
        }
    }

    let mut indices = Vec::new();
    for iz in 0..sz as usize {
        for ix in 0..sx as usize {
            let i0 = (iz * verts_x + ix) as u32;
            let i1 = i0 + 1;
            let i2 = i0 + verts_x as u32;
            let i3 = i2 + 1;
            indices.extend_from_slice(&[i0, i2, i1, i1, i2, i3]);
        }
    }

    let normals = compute_normals(&positions, &indices);
    Mesh3d {
        positions,
        normals,
        uvs,
        indices,
    }
}

pub fn build_terrain_mesh_from_image(
    img: &Rgba8Image,
    size: [f32; 3],
    segments_x: u32,
    segments_z: u32,
) -> Mesh3d {
    let (heights, w, h) = heights_from_rgba8(img);
    build_terrain_mesh(&heights, w, h, size, segments_x, segments_z)
}

pub fn terrain_camera_distance(camera: Vec3, center: [f32; 3]) -> f32 {
    let c = Vec3::new(center[0], center[1], center[2]);
    let dx = camera.x - c.x;
    let dy = camera.y - c.y;
    let dz = camera.z - c.z;
    (dx * dx + dy * dy + dz * dz).sqrt()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn flat_heightmap_produces_grid() {
        let heights = vec![0.5f32; 4];
        let mesh = build_terrain_mesh(&heights, 2, 2, [4.0, 2.0, 4.0], 2, 2);
        assert_eq!(mesh.vertex_count(), 9);
        assert_eq!(mesh.triangle_count(), 8);
        assert!((mesh.positions[1] - 0.0).abs() < 1e-4);
    }

    #[test]
    fn lod_halves_segments() {
        assert_eq!(lod_segment_count(32, 0), 32);
        assert_eq!(lod_segment_count(32, 1), 16);
        assert_eq!(lod_segment_count(32, 3), 4);
        assert_eq!(lod_segment_count(3, 2), 2);
    }

    #[test]
    fn select_lod_by_distance() {
        assert_eq!(select_terrain_lod(5.0, 10.0, 2), 0);
        assert_eq!(select_terrain_lod(25.0, 10.0, 2), 2);
        assert_eq!(select_terrain_lod(25.0, 10.0, 1), 1);
    }
}
