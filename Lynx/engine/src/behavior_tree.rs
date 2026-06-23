
use serde::{Deserialize, Serialize};

use crate::{Entity, Vec2};

pub type EntitySnap = (usize, f32, String);

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BehaviorTree {
    pub root: BtNode,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum BtNode {
    Sequence {
        children: Vec<BtNode>,
    },
    Selector {
        children: Vec<BtNode>,
    },
    Inverter {
        child: Box<BtNode>,
    },
    LeafPatrol {
        min_x: f32,
        max_x: f32,
        speed: f32,
    },
    LeafWait {
        duration: f32,
    },
    LeafChaseX {
        #[serde(default)]
        target_entity_id: Option<usize>,
        #[serde(default)]
        target_name: Option<String>,
        speed: f32,
    },
    LeafSetVelocity {
        vx: f32,
        vy: f32,
    },
    LeafIdle,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BtStatus {
    Running,
    Success,
    Failure,
}

#[derive(Clone, Debug, Default)]
pub struct BtState {
    pub stack: Vec<usize>,
    pub wait_remaining: f32,
    /// Активный узел для Play overlay (волна 10a).
    pub debug_path: String,
    pub debug_node_type: String,
    pub debug_running: bool,
}

#[derive(Clone, Debug, Serialize)]
pub struct BtDebugEntry {
    pub entity_id: usize,
    pub entity_name: String,
    pub path: String,
    pub node_type: String,
    pub running: bool,
}

fn node_type_name(node: &BtNode) -> &'static str {
    match node {
        BtNode::Sequence { .. } => "sequence",
        BtNode::Selector { .. } => "selector",
        BtNode::Inverter { .. } => "inverter",
        BtNode::LeafPatrol { .. } => "leaf_patrol",
        BtNode::LeafWait { .. } => "leaf_wait",
        BtNode::LeafChaseX { .. } => "leaf_chase_x",
        BtNode::LeafSetVelocity { .. } => "leaf_set_velocity",
        BtNode::LeafIdle => "leaf_idle",
    }
}

fn mark_running(e: &mut Entity, path: &str, node: &BtNode) {
    e.bt_state.debug_path = path.to_string();
    e.bt_state.debug_node_type = node_type_name(node).to_string();
    e.bt_state.debug_running = true;
}

fn clear_debug(e: &mut Entity) {
    e.bt_state.debug_path.clear();
    e.bt_state.debug_node_type.clear();
    e.bt_state.debug_running = false;
}

fn flip(s: BtStatus) -> BtStatus {
    match s {
        BtStatus::Success => BtStatus::Failure,
        BtStatus::Failure => BtStatus::Success,
        BtStatus::Running => BtStatus::Running,
    }
}

fn ensure_depth(st: &mut BtState, depth: usize) {
    while st.stack.len() <= depth {
        st.stack.push(0);
    }
}

fn resolve_target(snap: &[EntitySnap], id: Option<usize>, name: Option<&str>) -> Option<usize> {
    if let Some(i) = id {
        if snap.iter().any(|(eid, _, _)| *eid == i) {
            return Some(i);
        }
    }
    if let Some(n) = name {
        if let Some((eid, _, _)) = snap.iter().find(|(_, _, nm)| nm == n) {
            return Some(*eid);
        }
    }
    None
}

fn apply_patrol(e: &mut Entity, min_x: f32, max_x: f32, speed: f32) {
    let Some(phys) = e.physics.as_mut() else {
        return;
    };
    if phys.is_static {
        return;
    }
    let dir = if e.transform.pos.x < min_x {
        1.0
    } else if e.transform.pos.x > max_x {
        -1.0
    } else if phys.velocity.x.abs() < 1.0 {
        1.0
    } else {
        phys.velocity.x.signum()
    };
    let dir = if dir == 0.0 { 1.0 } else { dir };
    phys.velocity.x = dir * speed;
}

fn apply_chase_x(e: &mut Entity, snap: &[EntitySnap], target: Option<usize>, speed: f32) {
    let Some(phys) = e.physics.as_mut() else {
        return;
    };
    if phys.is_static {
        return;
    }
    let Some(tid) = target else {
        phys.velocity.x = 0.0;
        return;
    };
    let Some((_, tx, _)) = snap.iter().find(|(id, _, _)| *id == tid) else {
        phys.velocity.x = 0.0;
        return;
    };
    let dx = *tx - e.transform.pos.x;
    phys.velocity.x = if dx.abs() < 4.0 {
        0.0
    } else {
        dx.signum() * speed
    };
}

pub fn tick_r(
    node: &BtNode,
    e: &mut Entity,
    snap: &[EntitySnap],
    depth: usize,
    dt: f32,
    invert: bool,
    path: &str,
) -> BtStatus {
    let ty = node_type_name(node);
    let my_path = if path.is_empty() {
        ty.to_string()
    } else {
        format!("{path}/{ty}")
    };

    let mut status = match node {
        BtNode::Sequence { children } => {
            if children.is_empty() {
                BtStatus::Success
            } else {
                ensure_depth(&mut e.bt_state, depth);
                let i = e.bt_state.stack[depth];
                if i >= children.len() {
                    e.bt_state.stack[depth] = 0;
                    BtStatus::Success
                } else {
                    let child_path = format!("{my_path}[{i}]");
                    match tick_r(&children[i], e, snap, depth + 1, dt, false, &child_path) {
                        BtStatus::Failure => {
                            e.bt_state.stack[depth] = 0;
                            BtStatus::Failure
                        }
                        BtStatus::Running => BtStatus::Running,
                        BtStatus::Success => {
                            e.bt_state.stack[depth] = i + 1;
                            if e.bt_state.stack[depth] >= children.len() {
                                e.bt_state.stack[depth] = 0;
                                BtStatus::Success
                            } else {
                                let ni = e.bt_state.stack[depth];
                                let next_path = format!("{my_path}[{ni}]");
                                tick_r(&children[ni], e, snap, depth + 1, dt, false, &next_path)
                            }
                        }
                    }
                }
            }
        }
        BtNode::Selector { children } => {
            if children.is_empty() {
                BtStatus::Failure
            } else {
                ensure_depth(&mut e.bt_state, depth);
                let start = e.bt_state.stack[depth].min(children.len().saturating_sub(1));
                let mut result = BtStatus::Failure;
                for idx in start..children.len() {
                    e.bt_state.stack[depth] = idx;
                    let child_path = format!("{my_path}[{idx}]");
                    match tick_r(&children[idx], e, snap, depth + 1, dt, false, &child_path) {
                        BtStatus::Failure => continue,
                        BtStatus::Running => {
                            result = BtStatus::Running;
                            break;
                        }
                        BtStatus::Success => {
                            e.bt_state.stack[depth] = 0;
                            result = BtStatus::Success;
                            break;
                        }
                    }
                }
                if result == BtStatus::Failure {
                    e.bt_state.stack[depth] = 0;
                }
                result
            }
        }
        BtNode::Inverter { child } => {
            let child_path = format!("{my_path}/inv");
            tick_r(child, e, snap, depth, dt, true, &child_path)
        }
        BtNode::LeafPatrol { min_x, max_x, speed } => {
            apply_patrol(e, *min_x, *max_x, *speed);
            BtStatus::Running
        }
        BtNode::LeafWait { duration } => {
            if e.bt_state.wait_remaining <= 0.0 {
                e.bt_state.wait_remaining = *duration;
            }
            e.bt_state.wait_remaining -= dt;
            if e.bt_state.wait_remaining <= 0.0 {
                e.bt_state.wait_remaining = 0.0;
                BtStatus::Success
            } else {
                BtStatus::Running
            }
        }
        BtNode::LeafChaseX {
            target_entity_id,
            target_name,
            speed,
        } => {
            let tid = resolve_target(snap, *target_entity_id, target_name.as_deref());
            apply_chase_x(e, snap, tid, *speed);
            BtStatus::Running
        }
        BtNode::LeafSetVelocity { vx, vy } => {
            if let Some(phys) = e.physics.as_mut() {
                if !phys.is_static {
                    phys.velocity = Vec2::new(*vx, *vy);
                }
            }
            BtStatus::Success
        }
        BtNode::LeafIdle => {
            if let Some(phys) = e.physics.as_mut() {
                if !phys.is_static {
                    phys.velocity.x = 0.0;
                }
            }
            BtStatus::Running
        }
    };
    if invert {
        status = flip(status);
    }
    if status == BtStatus::Running && is_leaf_node(node) {
        mark_running(e, &my_path, node);
    } else if depth == 0 && status != BtStatus::Running {
        clear_debug(e);
    }
    status
}

fn is_leaf_node(node: &BtNode) -> bool {
    matches!(
        node,
        BtNode::LeafPatrol { .. }
            | BtNode::LeafWait { .. }
            | BtNode::LeafChaseX { .. }
            | BtNode::LeafSetVelocity { .. }
            | BtNode::LeafIdle
    )
}

pub fn collect_bt_debug(scene: &crate::Scene) -> Vec<BtDebugEntry> {
    scene
        .entities
        .iter()
        .filter(|e| e.behavior_tree.is_some())
        .map(|e| BtDebugEntry {
            entity_id: e.id,
            entity_name: e.name.clone(),
            path: e.bt_state.debug_path.clone(),
            node_type: e.bt_state.debug_node_type.clone(),
            running: e.bt_state.debug_running,
        })
        .collect()
}

pub fn tick_behavior_trees(scene: &mut crate::Scene, dt: f32) {
    let snap: Vec<EntitySnap> = scene
        .entities
        .iter()
        .map(|e| (e.id, e.transform.pos.x, e.name.clone()))
        .collect();

    let break_sub = scene.bt_break_subpath.clone();
    let step_once = scene.bt_step_armed;
    if step_once {
        scene.bt_step_armed = false;
    }
    let run_bt = !scene.paused || step_once;

    if !run_bt {
        return;
    }

    for e in &mut scene.entities {
        let Some(bt) = e.behavior_tree.clone() else {
            continue;
        };
        if let Some(ref sub) = break_sub {
            if !sub.is_empty()
                && e.bt_state.debug_running
                && e.bt_state.debug_path.contains(sub)
            {
                scene.paused = true;
                continue;
            }
        }
        let _ = tick_r(&bt.root, e, &snap, 0, dt, false, "root");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{Entity, Vec2};

    #[test]
    fn patrol_sets_debug_path() {
        let bt = BehaviorTree {
            root: BtNode::Sequence {
                children: vec![BtNode::LeafPatrol {
                    min_x: 0.0,
                    max_x: 100.0,
                    speed: 50.0,
                }],
            },
        };
        let mut e = Entity::new(2, "enemy", Vec2::new(50.0, 0.0), crate::Color::WHITE);
        e.physics = Some(crate::PhysicsBody {
            velocity: Vec2::ZERO,
            mass: 1.0,
            is_static: false,
            use_gravity: true,
            bounciness: 0.0,
            shape: crate::ColliderShape::Aabb,
            collision_layer: 1,
            collision_mask: u32::MAX,
            is_trigger: false,
            one_way: false,
        });
        e.behavior_tree = Some(bt);
        let snap = vec![(2, 50.0, "enemy".into())];
        let root = e.behavior_tree.as_ref().unwrap().root.clone();
        let st = tick_r(&root, &mut e, &snap, 0, 0.016, false, "root");
        assert_eq!(st, BtStatus::Running);
        assert!(e.bt_state.debug_path.contains("leaf_patrol"));
        assert!(e.bt_state.debug_running);
    }
}
