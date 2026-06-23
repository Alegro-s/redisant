//! LynxScript VM (M5a).

use std::collections::HashMap;

use super::compiler::{
    Op, Program, G_DT, G_KEY_A, G_KEY_D, G_KEY_SPACE, G_ON_GROUND, G_VX, G_VY, G_X, G_Y, N_ACTION,
    N_SET_VELOCITY,
};

#[derive(Clone, Debug)]
pub struct ScriptHost {
    pub x: f32,
    pub y: f32,
    pub vx: f32,
    pub vy: f32,
    pub dt: f32,
    pub on_ground: bool,
    pub key_a: bool,
    pub key_d: bool,
    pub key_space: bool,
    pub actions: HashMap<String, bool>,
    pub velocity_set: bool,
    pub out_vx: f32,
    pub out_vy: f32,
}

#[derive(Debug)]
pub enum VmError {
    Runtime(String),
}

pub fn run_script(prog: &Program, host: &mut ScriptHost) -> Result<(), VmError> {
    let mut ip = 0usize;
    let mut stack: Vec<f32> = Vec::with_capacity(12);
    while ip < prog.code.len() {
        match &prog.code[ip] {
            Op::LoadConst(v) => stack.push(*v),
            Op::LoadGlobal(id) => stack.push(read_global(host, *id)),
            Op::StoreGlobal(id) => {
                let v = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                write_global(host, *id, v);
            }
            Op::CallNative(id, _argc) => match *id {
                N_ACTION => {
                    let idx = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))? as usize;
                    let name = prog
                        .action_names
                        .get(idx)
                        .ok_or_else(|| VmError::Runtime("action idx".into()))?;
                    let pressed = host.actions.get(name).copied().unwrap_or(false);
                    stack.push(if pressed { 1.0 } else { 0.0 });
                }
                N_SET_VELOCITY => {
                    let vy = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                    let vx = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                    host.out_vx = vx;
                    host.out_vy = vy;
                    host.velocity_set = true;
                }
                _ => stack.push(0.0),
            },
            Op::Mul => {
                let b = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                let a = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                stack.push(a * b);
            }
            Op::Sub => {
                let b = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                let a = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                stack.push(a - b);
            }
            Op::JumpIfFalse(target) => {
                let v = stack.pop().ok_or_else(|| VmError::Runtime("stack".into()))?;
                if v == 0.0 {
                    ip = *target;
                    continue;
                }
            }
            Op::Jump(target) => {
                ip = *target;
                continue;
            }
            Op::End => break,
        }
        ip += 1;
    }
    Ok(())
}

fn read_global(host: &ScriptHost, id: u8) -> f32 {
    match id {
        G_X => host.x,
        G_Y => host.y,
        G_DT => host.dt,
        G_ON_GROUND => bool_f(host.on_ground),
        G_VX => host.vx,
        G_VY => host.vy,
        G_KEY_A => bool_f(host.key_a),
        G_KEY_D => bool_f(host.key_d),
        G_KEY_SPACE => bool_f(host.key_space),
        _ => 0.0,
    }
}

fn write_global(host: &mut ScriptHost, id: u8, v: f32) {
    match id {
        G_X => host.x = v,
        G_Y => host.y = v,
        _ => {}
    }
}

fn bool_f(b: bool) -> f32 {
    if b {
        1.0
    } else {
        0.0
    }
}
