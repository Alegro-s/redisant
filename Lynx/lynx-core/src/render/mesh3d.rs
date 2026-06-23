//! Примитивы 3D-мешей (без GLTF в hot path; GLB — опциональный импорт).

#[derive(Clone, Debug)]
pub struct Mesh3d {
    pub positions: Vec<f32>,
    pub normals: Vec<f32>,
    /// `TEXCOORD_0`, len = vertex_count * 2; generated for primitives if empty.
    pub uvs: Vec<f32>,
    pub indices: Vec<u32>,
}

impl Mesh3d {
    pub fn vertex_count(&self) -> usize {
        self.positions.len() / 3
    }

    pub fn triangle_count(&self) -> usize {
        self.indices.len() / 3
    }

    /// Куб [-0.5, 0.5] (как `LynxGlbMesh.unitCube` в Dart).
    pub fn unit_cube() -> Self {
        let positions = vec![
            -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5, -0.5, -0.5, 0.5,
            0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5,
        ];
        let indices = vec![
            0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 0, 4, 5, 0, 5, 1, 2, 6, 7, 2, 7, 3, 0, 3, 7, 0,
            7, 4, 1, 5, 6, 1, 6, 2,
        ];
        let normals = compute_normals(&positions, &indices);
        let uvs = box_uvs_for_cube();
        Self {
            positions,
            normals,
            uvs,
            indices,
        }
    }

    pub fn ensure_uvs(&mut self) {
        if !self.uvs.is_empty() && self.uvs.len() == self.vertex_count() * 2 {
            return;
        }
        self.uvs = box_uvs_for_cube();
        if self.uvs.len() != self.vertex_count() * 2 {
            self.uvs = planar_uvs(&self.positions);
        }
    }

    /// AABB-куб из `halfExtents` (масштаб в model matrix).
    pub fn box_from_half_extents(hx: f32, hy: f32, hz: f32) -> Self {
        let mut m = Self::unit_cube();
        for i in (0..m.positions.len()).step_by(3) {
            m.positions[i] *= hx * 2.0;
            m.positions[i + 1] *= hy * 2.0;
            m.positions[i + 2] *= hz * 2.0;
        }
        m.normals = compute_normals(&m.positions, &m.indices);
        m.ensure_uvs();
        m
    }
}

/// UV для 8 вершин unit cube (per-face 0..1).
fn box_uvs_for_cube() -> Vec<f32> {
    vec![
        0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0,
    ]
}

fn planar_uvs(positions: &[f32]) -> Vec<f32> {
    let n = positions.len() / 3;
    let mut uvs = vec![0.0f32; n * 2];
    for i in 0..n {
        uvs[i * 2] = positions[i * 3] + 0.5;
        uvs[i * 2 + 1] = positions[i * 3 + 1] + 0.5;
    }
    uvs
}

pub fn compute_normals(positions: &[f32], indices: &[u32]) -> Vec<f32> {
    let n = positions.len() / 3;
    let mut normals = vec![0.0f32; positions.len()];
    for tri in indices.chunks(3) {
        if tri.len() < 3 {
            continue;
        }
        let i0 = tri[0] as usize * 3;
        let i1 = tri[1] as usize * 3;
        let i2 = tri[2] as usize * 3;
        if i0 + 2 >= positions.len() || i1 + 2 >= positions.len() || i2 + 2 >= positions.len() {
            continue;
        }
        let ax = positions[i1] - positions[i0];
        let ay = positions[i1 + 1] - positions[i0 + 1];
        let az = positions[i1 + 2] - positions[i0 + 2];
        let bx = positions[i2] - positions[i0];
        let by = positions[i2 + 1] - positions[i0 + 1];
        let bz = positions[i2 + 2] - positions[i0 + 2];
        let nx = ay * bz - az * by;
        let ny = az * bx - ax * bz;
        let nz = ax * by - ay * bx;
        for &vi in tri {
            let o = vi as usize * 3;
            normals[o] += nx;
            normals[o + 1] += ny;
            normals[o + 2] += nz;
        }
    }
    for i in 0..n {
        let o = i * 3;
        let len = (normals[o] * normals[o] + normals[o + 1] * normals[o + 1] + normals[o + 2] * normals[o + 2])
            .sqrt();
        if len > 1e-6 {
            normals[o] /= len;
            normals[o + 1] /= len;
            normals[o + 2] /= len;
        } else {
            normals[o + 1] = 1.0;
        }
    }
    normals
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unit_cube_has_uvs() {
        let m = Mesh3d::unit_cube();
        assert_eq!(m.uvs.len(), m.vertex_count() * 2);
    }
}
