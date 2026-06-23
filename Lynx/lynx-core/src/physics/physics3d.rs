//! M14a: 3D AABB colliders + rigid body (свой solver, без Rapier).

use crate::scene3d::{Lynx3dObject, Lynx3dRoom, Lynx3dScene};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BodyType3d {
    Static,
    Dynamic,
}

#[derive(Clone, Debug)]
pub struct RigidBody3d {
    pub id: String,
    pub body_type: BodyType3d,
    pub position: [f32; 3],
    pub velocity: [f32; 3],
    pub half_extents: [f32; 3],
    pub restitution: f32,
    pub friction: f32,
}

#[derive(Clone, Debug)]
pub struct StaticPlane3d {
    /// Нормаль (unit) наружу из допустимой полупространства.
    pub normal: [f32; 3],
    /// d в уравнении dot(n, p) >= d (точка на плоскости).
    pub d: f32,
}

#[derive(Clone, Debug)]
pub struct Physics3dWorld {
    pub gravity: [f32; 3],
    pub bodies: Vec<RigidBody3d>,
    pub static_planes: Vec<StaticPlane3d>,
    pub hinge_joints: Vec<HingeJoint3d>,
}

#[derive(Clone, Debug)]
pub struct HingeJoint3d {
    pub body_a: String,
    pub body_b: String,
    pub anchor: [f32; 3],
    pub axis: [f32; 3],
    pub min_angle_deg: f32,
    pub max_angle_deg: f32,
}

impl Physics3dWorld {
    pub fn new() -> Self {
        Self {
            gravity: [0.0, -9.81, 0.0],
            bodies: Vec::new(),
            static_planes: Vec::new(),
            hinge_joints: Vec::new(),
        }
    }

    pub fn from_lynx3d_scene(scene: &Lynx3dScene) -> Self {
        let mut world = Self::new();
        world.gravity = scene.gravity;
        if let Some(room) = &scene.room {
            world.static_planes.extend(room_planes(room));
        }
        for obj in &scene.objects {
            world.bodies.push(rigid_from_object(obj));
        }
        world.hinge_joints = scene
            .physics_joints
            .iter()
            .map(|j| HingeJoint3d {
                body_a: j.body_a.clone(),
                body_b: j.body_b.clone(),
                anchor: j.anchor,
                axis: j.axis,
                min_angle_deg: j.min_angle_deg,
                max_angle_deg: j.max_angle_deg,
            })
            .collect();
        world
    }

    pub fn dynamic_count(&self) -> usize {
        self.bodies
            .iter()
            .filter(|b| b.body_type == BodyType3d::Dynamic)
            .count()
    }

    pub fn step(&mut self, dt: f32) {
        let dt = dt.clamp(0.0, 1.0 / 15.0);
        if dt <= 0.0 {
            return;
        }
        let g = self.gravity;
        for body in &mut self.bodies {
            if body.body_type != BodyType3d::Dynamic {
                continue;
            }
            body.velocity[0] += g[0] * dt;
            body.velocity[1] += g[1] * dt;
            body.velocity[2] += g[2] * dt;
            body.position[0] += body.velocity[0] * dt;
            body.position[1] += body.velocity[1] * dt;
            body.position[2] += body.velocity[2] * dt;
        }
        for i in 0..self.bodies.len() {
            if self.bodies[i].body_type != BodyType3d::Dynamic {
                continue;
            }
            resolve_static_planes(&mut self.bodies[i], &self.static_planes);
        }
        let n = self.bodies.len();
        for i in 0..n {
            if self.bodies[i].body_type != BodyType3d::Dynamic {
                continue;
            }
            for j in (i + 1)..n {
                if self.bodies[j].body_type != BodyType3d::Dynamic {
                    continue;
                }
                let (left, right) = self.bodies.split_at_mut(j);
                resolve_pair(&mut left[i], &mut right[0]);
            }
        }
        resolve_hinge_joints(&mut self.bodies, &self.hinge_joints);
    }

    pub fn body_index(&self, id: &str) -> Option<usize> {
        self.bodies.iter().position(|b| b.id == id)
    }

    pub fn positions_map(&self) -> Vec<(String, [f32; 3])> {
        self.bodies
            .iter()
            .map(|b| (b.id.clone(), b.position))
            .collect()
    }
}

fn rigid_from_object(obj: &Lynx3dObject) -> RigidBody3d {
    let body_type = if obj.is_static {
        BodyType3d::Static
    } else {
        BodyType3d::Dynamic
    };
    RigidBody3d {
        id: obj.id.clone(),
        body_type,
        position: obj.position,
        velocity: [0.0, 0.0, 0.0],
        half_extents: obj.half_extents,
        restitution: obj.restitution,
        friction: obj.friction,
    }
}

fn room_planes(room: &Lynx3dRoom) -> Vec<StaticPlane3d> {
    let cx = room.center[0];
    let cy = room.center[1];
    let cz = room.center[2];
    let hw = room.width * 0.5;
    let hh = room.height * 0.5;
    let hd = room.depth * 0.5;
    vec![
        StaticPlane3d {
            normal: [0.0, 1.0, 0.0],
            d: cy - hh,
        },
        StaticPlane3d {
            normal: [0.0, -1.0, 0.0],
            d: -(cy + hh),
        },
        StaticPlane3d {
            normal: [1.0, 0.0, 0.0],
            d: cx - hw,
        },
        StaticPlane3d {
            normal: [-1.0, 0.0, 0.0],
            d: -(cx + hw),
        },
        StaticPlane3d {
            normal: [0.0, 0.0, 1.0],
            d: cz - hd,
        },
        StaticPlane3d {
            normal: [0.0, 0.0, -1.0],
            d: -(cz + hd),
        },
    ]
}

fn resolve_static_planes(body: &mut RigidBody3d, planes: &[StaticPlane3d]) {
    for plane in planes {
        let n = plane.normal;
        let r = support_radius_on_axis(body.half_extents, n);
        let dist = dot3(body.position, n) - r - plane.d;
        if dist < 0.0 {
            body.position[0] -= n[0] * dist;
            body.position[1] -= n[1] * dist;
            body.position[2] -= n[2] * dist;
            let vn = dot3(body.velocity, n);
            if vn < 0.0 {
                let bounce = -(1.0 + body.restitution) * vn;
                body.velocity[0] += n[0] * bounce;
                body.velocity[1] += n[1] * bounce;
                body.velocity[2] += n[2] * bounce;
                let t0 = body.velocity[0] - n[0] * vn;
                let t1 = body.velocity[1] - n[1] * vn;
                let t2 = body.velocity[2] - n[2] * vn;
                let f = 1.0 - body.friction;
                body.velocity[0] = t0 * f;
                body.velocity[1] = t1 * f;
                body.velocity[2] = t2 * f;
            }
        }
    }
}

fn resolve_pair(a: &mut RigidBody3d, b: &mut RigidBody3d) {
    let dx = b.position[0] - a.position[0];
    let dy = b.position[1] - a.position[1];
    let dz = b.position[2] - a.position[2];
    let overlap_x = (a.half_extents[0] + b.half_extents[0]) - dx.abs();
    let overlap_y = (a.half_extents[1] + b.half_extents[1]) - dy.abs();
    let overlap_z = (a.half_extents[2] + b.half_extents[2]) - dz.abs();
    if overlap_x <= 0.0 || overlap_y <= 0.0 || overlap_z <= 0.0 {
        return;
    }
    let sep = if overlap_x <= overlap_y && overlap_x <= overlap_z {
        let sign = if dx >= 0.0 { 1.0 } else { -1.0 };
        [sign * overlap_x * 0.5, 0.0, 0.0]
    } else if overlap_y <= overlap_z {
        let sign = if dy >= 0.0 { 1.0 } else { -1.0 };
        [0.0, sign * overlap_y * 0.5, 0.0]
    } else {
        let sign = if dz >= 0.0 { 1.0 } else { -1.0 };
        [0.0, 0.0, sign * overlap_z * 0.5]
    };
    a.position[0] -= sep[0];
    a.position[1] -= sep[1];
    a.position[2] -= sep[2];
    b.position[0] += sep[0];
    b.position[1] += sep[1];
    b.position[2] += sep[2];
    let e = (a.restitution + b.restitution) * 0.5;
    let rvx = b.velocity[0] - a.velocity[0];
    let rvy = b.velocity[1] - a.velocity[1];
    let rvz = b.velocity[2] - a.velocity[2];
    if sep[0].abs() > 1e-6 && rvx < 0.0 {
        let imp = -(1.0 + e) * rvx * 0.5;
        a.velocity[0] -= imp;
        b.velocity[0] += imp;
    }
    if sep[1].abs() > 1e-6 && rvy < 0.0 {
        let imp = -(1.0 + e) * rvy * 0.5;
        a.velocity[1] -= imp;
        b.velocity[1] += imp;
    }
    if sep[2].abs() > 1e-6 && rvz < 0.0 {
        let imp = -(1.0 + e) * rvz * 0.5;
        a.velocity[2] -= imp;
        b.velocity[2] += imp;
    }
}

fn dot3(a: [f32; 3], b: [f32; 3]) -> f32 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

fn support_radius_on_axis(he: [f32; 3], axis: [f32; 3]) -> f32 {
    he[0] * axis[0].abs() + he[1] * axis[1].abs() + he[2] * axis[2].abs()
}

/// Level 2: soft hinge — keeps body_b near arc around anchor relative to body_a.
fn resolve_hinge_joints(bodies: &mut [RigidBody3d], joints: &[HingeJoint3d]) {
    for joint in joints {
        let Some(ia) = bodies.iter().position(|b| b.id == joint.body_a) else {
            continue;
        };
        let Some(ib) = bodies.iter().position(|b| b.id == joint.body_b) else {
            continue;
        };
        if ia == ib {
            continue;
        }
        let (left, right) = if ia < ib {
            let (a, b) = bodies.split_at_mut(ib);
            (&mut a[ia], &mut b[0])
        } else {
            let (a, b) = bodies.split_at_mut(ia);
            (&mut b[0], &mut a[ib])
        };
        if left.body_type != BodyType3d::Dynamic && right.body_type != BodyType3d::Dynamic {
            continue;
        }
        let anchor = joint.anchor;
        let axis = joint.axis;
        let mut rel = [
            right.position[0] - anchor[0],
            right.position[1] - anchor[1],
            right.position[2] - anchor[2],
        ];
        let proj = dot3(rel, axis);
        rel[0] -= axis[0] * proj;
        rel[1] -= axis[1] * proj;
        rel[2] -= axis[2] * proj;
        let len = (rel[0] * rel[0] + rel[1] * rel[1] + rel[2] * rel[2]).sqrt().max(1e-4);
        rel[0] /= len;
        rel[1] /= len;
        rel[2] /= len;
        let target_dist = 1.2f32;
        let desired = [
            anchor[0] + rel[0] * target_dist,
            anchor[1] + rel[1] * target_dist,
            anchor[2] + rel[2] * target_dist,
        ];
        if right.body_type == BodyType3d::Dynamic {
            right.position[0] += (desired[0] - right.position[0]) * 0.15;
            right.position[1] += (desired[1] - right.position[1]) * 0.15;
            right.position[2] += (desired[2] - right.position[2]) * 0.15;
            right.velocity[0] *= 0.98;
            right.velocity[1] *= 0.98;
            right.velocity[2] *= 0.98;
        }
        let _ = (joint.min_angle_deg, joint.max_angle_deg, left);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scene3d::Lynx3dRoom;

    #[test]
    fn dynamic_falls_and_hits_floor() {
        let mut world = Physics3dWorld::new();
        world.gravity = [0.0, -10.0, 0.0];
        world.static_planes.push(StaticPlane3d {
            normal: [0.0, 1.0, 0.0],
            d: 0.0,
        });
        world.bodies.push(RigidBody3d {
            id: "box".into(),
            body_type: BodyType3d::Dynamic,
            position: [0.0, 2.0, 0.0],
            velocity: [0.0, 0.0, 0.0],
            half_extents: [0.5, 0.5, 0.5],
            restitution: 0.0,
            friction: 0.9,
        });
        for _ in 0..120 {
            world.step(1.0 / 60.0);
        }
        assert!(world.bodies[0].position[1] >= 0.5 - 0.05);
        assert!(world.bodies[0].velocity[1].abs() < 0.5);
    }

    #[test]
    fn two_boxes_separate() {
        let mut world = Physics3dWorld::new();
        world.bodies.push(RigidBody3d {
            id: "a".into(),
            body_type: BodyType3d::Dynamic,
            position: [0.0, 0.0, 0.0],
            velocity: [0.0, 0.0, 0.0],
            half_extents: [0.5, 0.5, 0.5],
            restitution: 0.0,
            friction: 0.5,
        });
        world.bodies.push(RigidBody3d {
            id: "b".into(),
            body_type: BodyType3d::Dynamic,
            position: [0.3, 0.0, 0.0],
            velocity: [0.0, 0.0, 0.0],
            half_extents: [0.5, 0.5, 0.5],
            restitution: 0.0,
            friction: 0.5,
        });
        world.step(1.0 / 60.0);
        let dx = (world.bodies[1].position[0] - world.bodies[0].position[0]).abs();
        assert!(dx >= 0.95);
    }

    #[test]
    fn from_scene_with_room() {
        let scene = Lynx3dScene {
            active: true,
            gravity: [0.0, -9.81, 0.0],
            ambient_color: [0.2, 0.2, 0.2],
            render: Default::default(),
            camera: Default::default(),
            culling: Default::default(),
            room: Some(Lynx3dRoom {
                width: 8.0,
                height: 4.0,
                depth: 8.0,
                center: [0.0, 2.0, 0.0],
            }),
            terrain: None,
            objects: vec![Lynx3dObject {
                id: "crate".into(),
                mesh_path: None,
                position: [0.0, 3.0, 0.0],
                rotation_euler_deg: [0.0, 0.0, 0.0],
                scale: [1.0, 1.0, 1.0],
                half_extents: [0.5, 0.5, 0.5],
                color_rgba: 0xFFFFFFFF,
                metallic: 0.0,
                roughness: 0.5,
                albedo_texture: None,
                normal_texture: None,
                metallic_roughness_texture: None,
                animation_clip: None,
                animation_time_sec: 0.0,
                is_static: false,
                restitution: 0.1,
                friction: 0.6,
            }],
            physics_joints: Vec::new(),
        };
        let mut world = Physics3dWorld::from_lynx3d_scene(&scene);
        assert_eq!(world.static_planes.len(), 6);
        for _ in 0..90 {
            world.step(1.0 / 60.0);
        }
        assert!(world.bodies[0].position[1] > 0.0);
    }
}
