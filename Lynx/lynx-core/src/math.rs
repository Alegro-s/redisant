//! Математика движка — только std, без glam/glamer.

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

impl Vec2 {
    pub const ZERO: Self = Self { x: 0.0, y: 0.0 };

    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

impl Vec3 {
    pub const ZERO: Self = Self {
        x: 0.0,
        y: 0.0,
        z: 0.0,
    };

    pub fn new(x: f32, y: f32, z: f32) -> Self {
        Self { x, y, z }
    }

    pub fn dot(self, o: Self) -> f32 {
        self.x * o.x + self.y * o.y + self.z * o.z
    }

    pub fn cross(self, o: Self) -> Self {
        Self {
            x: self.y * o.z - self.z * o.y,
            y: self.z * o.x - self.x * o.z,
            z: self.x * o.y - self.y * o.x,
        }
    }

    pub fn len_sq(self) -> f32 {
        self.dot(self)
    }

    pub fn normalized(self) -> Self {
        let l = self.len_sq().sqrt();
        if l <= f32::EPSILON {
            Self::ZERO
        } else {
            Self {
                x: self.x / l,
                y: self.y / l,
                z: self.z / l,
            }
        }
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct Mat4 {
    pub m: [f32; 16],
}

impl Mat4 {
    pub fn identity() -> Self {
        let mut m = [0.0; 16];
        m[0] = 1.0;
        m[5] = 1.0;
        m[10] = 1.0;
        m[15] = 1.0;
        Self { m }
    }

    pub fn multiply(self, rhs: Self) -> Self {
        let mut out = [0.0; 16];
        for col in 0..4 {
            for row in 0..4 {
                let mut s = 0.0f32;
                for k in 0..4 {
                    s += self.m[k * 4 + row] * rhs.m[col * 4 + k];
                }
                out[col * 4 + row] = s;
            }
        }
        Self { m: out }
    }

    pub fn translation(v: Vec3) -> Self {
        let mut m = Self::identity().m;
        m[12] = v.x;
        m[13] = v.y;
        m[14] = v.z;
        Self { m }
    }

    pub fn scale_vec(v: Vec3) -> Self {
        let mut m = [0.0; 16];
        m[0] = v.x;
        m[5] = v.y;
        m[10] = v.z;
        m[15] = 1.0;
        Self { m }
    }

    pub fn rotation_y(deg: f32) -> Self {
        let r = deg.to_radians();
        let (s, c) = r.sin_cos();
        let mut m = Self::identity().m;
        m[0] = c;
        m[2] = -s;
        m[8] = s;
        m[10] = c;
        Self { m }
    }

    pub fn rotation_euler_xyz_deg(euler: [f32; 3]) -> Self {
        let rx = euler[0].to_radians();
        let ry = euler[1].to_radians();
        let rz = euler[2].to_radians();
        let (sx, cx) = rx.sin_cos();
        let (sy, cy) = ry.sin_cos();
        let (sz, cz) = rz.sin_cos();
        let rx_m = Self {
            m: [1.0, 0.0, 0.0, 0.0, 0.0, cx, sx, 0.0, 0.0, -sx, cx, 0.0, 0.0, 0.0, 0.0, 1.0],
        };
        let ry_m = Self {
            m: [cy, 0.0, -sy, 0.0, 0.0, 1.0, 0.0, 0.0, sy, 0.0, cy, 0.0, 0.0, 0.0, 0.0, 1.0],
        };
        let rz_m = Self {
            m: [cz, sz, 0.0, 0.0, -sz, cz, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0],
        };
        rz_m.multiply(ry_m).multiply(rx_m)
    }

    pub fn from_quat(q: [f32; 4]) -> Self {
        let (x, y, z, w) = (q[0], q[1], q[2], q[3]);
        let mut m = [0.0; 16];
        m[0] = 1.0 - 2.0 * (y * y + z * z);
        m[5] = 1.0 - 2.0 * (x * x + z * z);
        m[10] = 1.0 - 2.0 * (x * x + y * y);
        m[15] = 1.0;
        m[4] = 2.0 * (x * y + z * w);
        m[1] = 2.0 * (x * y - z * w);
        m[8] = 2.0 * (x * z - y * w);
        m[2] = 2.0 * (x * z + y * w);
        m[9] = 2.0 * (y * z + x * w);
        m[6] = 2.0 * (y * z - x * w);
        Self { m }
    }

    pub fn transform_point(self, p: Vec3) -> Vec3 {
        let x = self.m[0] * p.x + self.m[4] * p.y + self.m[8] * p.z + self.m[12];
        let y = self.m[1] * p.x + self.m[5] * p.y + self.m[9] * p.z + self.m[13];
        let z = self.m[2] * p.x + self.m[6] * p.y + self.m[10] * p.z + self.m[14];
        Vec3::new(x, y, z)
    }

    pub fn model_trs(position: [f32; 3], euler_deg: [f32; 3], scale: [f32; 3]) -> Self {
        Self::translation(Vec3::new(position[0], position[1], position[2]))
            .multiply(Self::rotation_euler_xyz_deg(euler_deg))
            .multiply(Self::scale_vec(Vec3::new(
                scale[0].max(0.001),
                scale[1].max(0.001),
                scale[2].max(0.001),
            )))
    }

    pub fn perspective_rh(fov_y_deg: f32, aspect: f32, near: f32, far: f32) -> Self {
        let f = 1.0 / (fov_y_deg.to_radians() * 0.5).tan();
        let nf = 1.0 / (near - far);
        let mut m = [0.0; 16];
        m[0] = f / aspect;
        m[5] = f;
        m[10] = far * nf;
        m[11] = -1.0;
        m[14] = near * far * nf;
        Self { m }
    }

    pub fn look_at_rh(eye: Vec3, target: Vec3, up: Vec3) -> Self {
        let z = (eye - target).normalized();
        let x = up.cross(z).normalized();
        let y = z.cross(x);
        let mut m = Self::identity().m;
        m[0] = x.x;
        m[4] = x.y;
        m[8] = x.z;
        m[1] = y.x;
        m[5] = y.y;
        m[9] = y.z;
        m[2] = z.x;
        m[6] = z.y;
        m[10] = z.z;
        m[12] = -x.dot(eye);
        m[13] = -y.dot(eye);
        m[14] = -z.dot(eye);
        Self { m }
    }

    pub fn orthographic_rh(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Self {
        let mut m = [0.0; 16];
        m[0] = 2.0 / (right - left);
        m[5] = 2.0 / (top - bottom);
        m[10] = 1.0 / (near - far);
        m[12] = (left + right) / (left - right);
        m[13] = (bottom + top) / (bottom - top);
        m[14] = near / (near - far);
        m[15] = 1.0;
        Self { m }
    }
}

impl std::ops::Sub for Vec3 {
    type Output = Self;
    fn sub(self, rhs: Self) -> Self {
        Self {
            x: self.x - rhs.x,
            y: self.y - rhs.y,
            z: self.z - rhs.z,
        }
    }
}

impl std::ops::Mul<f32> for Vec3 {
    type Output = Self;
    fn mul(self, s: f32) -> Self {
        Self {
            x: self.x * s,
            y: self.y * s,
            z: self.z * s,
        }
    }
}

/// World-space AABB (M14b culling).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Aabb3 {
    pub min: Vec3,
    pub max: Vec3,
}

impl Aabb3 {
    pub fn from_center_half_extents(center: Vec3, half: Vec3) -> Self {
        Self {
            min: Vec3::new(center.x - half.x, center.y - half.y, center.z - half.z),
            max: Vec3::new(center.x + half.x, center.y + half.y, center.z + half.z),
        }
    }

    pub fn corners(&self) -> [Vec3; 8] {
        let (mn, mx) = (self.min, self.max);
        [
            Vec3::new(mn.x, mn.y, mn.z),
            Vec3::new(mx.x, mn.y, mn.z),
            Vec3::new(mn.x, mx.y, mn.z),
            Vec3::new(mx.x, mx.y, mn.z),
            Vec3::new(mn.x, mn.y, mx.z),
            Vec3::new(mx.x, mn.y, mx.z),
            Vec3::new(mn.x, mx.y, mx.z),
            Vec3::new(mx.x, mx.y, mx.z),
        ]
    }

    pub fn transform_by(&self, m: Mat4) -> Self {
        let mut mn = Vec3::new(f32::INFINITY, f32::INFINITY, f32::INFINITY);
        let mut mx = Vec3::new(f32::NEG_INFINITY, f32::NEG_INFINITY, f32::NEG_INFINITY);
        for p in self.corners().map(|c| m.transform_point(c)) {
            mn.x = mn.x.min(p.x);
            mn.y = mn.y.min(p.y);
            mn.z = mn.z.min(p.z);
            mx.x = mx.x.max(p.x);
            mx.y = mx.y.max(p.y);
            mx.z = mx.z.max(p.z);
        }
        Self { min: mn, max: mx }
    }

    pub fn merge(self, other: Self) -> Self {
        Self {
            min: Vec3::new(
                self.min.x.min(other.min.x),
                self.min.y.min(other.min.y),
                self.min.z.min(other.min.z),
            ),
            max: Vec3::new(
                self.max.x.max(other.max.x),
                self.max.y.max(other.max.y),
                self.max.z.max(other.max.z),
            ),
        }
    }
}

/// View frustum from `view_proj` (column-major, RH).
#[derive(Clone, Copy, Debug)]
pub struct Frustum {
    planes: [[f32; 4]; 6],
}

impl Frustum {
    pub fn from_view_proj(m: &Mat4) -> Self {
        let v = &m.m;
        let mut planes = [
            [v[3] + v[0], v[7] + v[4], v[11] + v[8], v[15] + v[12]],
            [v[3] - v[0], v[7] - v[4], v[11] - v[8], v[15] - v[12]],
            [v[3] + v[1], v[7] + v[5], v[11] + v[9], v[15] + v[13]],
            [v[3] - v[1], v[7] - v[5], v[11] - v[9], v[15] - v[13]],
            [v[3] + v[2], v[7] + v[6], v[11] + v[10], v[15] + v[14]],
            [v[3] - v[2], v[7] - v[6], v[11] - v[10], v[15] - v[14]],
        ];
        for p in &mut planes {
            let inv_len = (p[0] * p[0] + p[1] * p[1] + p[2] * p[2]).sqrt().max(f32::EPSILON);
            p[0] /= inv_len;
            p[1] /= inv_len;
            p[2] /= inv_len;
            p[3] /= inv_len;
        }
        Self { planes }
    }

    pub fn intersects_aabb(&self, aabb: &Aabb3) -> bool {
        for plane in &self.planes {
            if aabb.corners().iter().all(|c| plane_distance(plane, *c) < 0.0) {
                return false;
            }
        }
        true
    }
}

fn plane_distance(plane: &[f32; 4], p: Vec3) -> f32 {
    plane[0] * p.x + plane[1] * p.y + plane[2] * p.z + plane[3]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn vec3_dot() {
        let a = Vec3 {
            x: 1.0,
            y: 0.0,
            z: 0.0,
        };
        let b = Vec3 {
            x: 1.0,
            y: 1.0,
            z: 0.0,
        };
        assert!((a.dot(b) - 1.0).abs() < 1e-5);
    }

    #[test]
    fn frustum_culls_far_aabb() {
        let view = Mat4::look_at_rh(
            Vec3::new(0.0, 2.0, 8.0),
            Vec3::new(0.0, 2.0, 0.0),
            Vec3::new(0.0, 1.0, 0.0),
        );
        let proj = Mat4::perspective_rh(60.0, 16.0 / 9.0, 0.1, 100.0);
        let frustum = Frustum::from_view_proj(&proj.multiply(view));
        let he = Vec3::new(1.0, 1.0, 1.0);
        let near = Aabb3::from_center_half_extents(Vec3::new(0.0, 2.0, 0.0), he);
        let far = Aabb3::from_center_half_extents(Vec3::new(0.0, 2.0, -200.0), he);
        assert!(frustum.intersects_aabb(&near));
        assert!(!frustum.intersects_aabb(&far));
    }
}
