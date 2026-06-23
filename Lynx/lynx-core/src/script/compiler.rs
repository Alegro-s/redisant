//! LynxScript compiler (M5a subset).

#[derive(Clone, Debug, PartialEq)]
pub enum Op {
    LoadConst(f32),
    LoadGlobal(u8),
    StoreGlobal(u8),
    CallNative(u8, u8),
    Mul,
    Sub,
    JumpIfFalse(usize),
    Jump(usize),
    End,
}

#[derive(Clone, Debug)]
pub struct Program {
    pub code: Vec<Op>,
    pub action_names: Vec<String>,
}

#[derive(Debug)]
pub enum CompileError {
    Syntax(String),
}

pub const G_X: u8 = 0;
pub const G_Y: u8 = 1;
pub const G_DT: u8 = 2;
pub const G_ON_GROUND: u8 = 3;
pub const G_VX: u8 = 4;
pub const G_VY: u8 = 5;
pub const G_KEY_A: u8 = 6;
pub const G_KEY_D: u8 = 7;
pub const G_KEY_SPACE: u8 = 8;

pub const N_ACTION: u8 = 0;
pub const N_SET_VELOCITY: u8 = 1;

pub fn compile(source: &str) -> Result<Program, CompileError> {
    let body = source
        .trim_start()
        .strip_prefix(super::MAGIC_PREFIX)
        .ok_or_else(|| CompileError::Syntax("missing #lynxscript".into()))?
        .trim();
    let lines: Vec<&str> = body
        .lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty())
        .collect();
    let mut code = Vec::new();
    let mut action_names = Vec::new();
    let mut i = 0;
    compile_block(&lines, &mut i, &mut code, &mut action_names)?;
    code.push(Op::End);
    Ok(Program { code, action_names })
}

fn compile_block(
    lines: &[&str],
    i: &mut usize,
    code: &mut Vec<Op>,
    actions: &mut Vec<String>,
) -> Result<(), CompileError> {
    while *i < lines.len() {
        let line = lines[*i];
        if line == "end" {
            *i += 1;
            return Ok(());
        }
        if line.starts_with("function on_signal") {
            skip_until_end(lines, i);
            continue;
        }
        if let Some(cond) = parse_if_head(line) {
            emit_condition(cond, code, actions)?;
            let jump_false = code.len();
            code.push(Op::JumpIfFalse(0));
            *i += 1;
            compile_block(lines, i, code, actions)?;
            let end = code.len();
            if let Op::JumpIfFalse(ref mut t) = code[jump_false] {
                *t = end;
            }
            continue;
        }
        if line.starts_with("set_velocity(") {
            emit_set_velocity(line, code)?;
            *i += 1;
            continue;
        }
        if line.starts_with("y = y -") {
            emit_y_sub_dt(code, line)?;
            *i += 1;
            continue;
        }
        return Err(CompileError::Syntax(format!("unsupported: {line}")));
    }
    Ok(())
}

fn skip_until_end(lines: &[&str], i: &mut usize) {
    *i += 1;
    while *i < lines.len() {
        if lines[*i] == "end" {
            *i += 1;
            return;
        }
        *i += 1;
    }
}

enum IfCond<'a> {
    KeyA,
    KeyD,
    KeySpace,
    OnGround,
    Action(&'a str),
}

fn parse_if_head(line: &str) -> Option<IfCond<'_>> {
    let rest = line.strip_prefix("if ")?.strip_suffix(" then")?.trim();
    match rest {
        "key_a" => Some(IfCond::KeyA),
        "key_d" => Some(IfCond::KeyD),
        "key_space" => Some(IfCond::KeySpace),
        "on_ground" => Some(IfCond::OnGround),
        _ if rest.starts_with("action_pressed(") => {
            let inner = rest
                .strip_prefix("action_pressed(")?
                .strip_suffix(')')?
                .trim()
                .trim_matches('"');
            Some(IfCond::Action(inner))
        }
        _ => None,
    }
}

fn emit_condition(
    cond: IfCond<'_>,
    code: &mut Vec<Op>,
    actions: &mut Vec<String>,
) -> Result<(), CompileError> {
    match cond {
        IfCond::KeyA => code.push(Op::LoadGlobal(G_KEY_A)),
        IfCond::KeyD => code.push(Op::LoadGlobal(G_KEY_D)),
        IfCond::KeySpace => code.push(Op::LoadGlobal(G_KEY_SPACE)),
        IfCond::OnGround => code.push(Op::LoadGlobal(G_ON_GROUND)),
        IfCond::Action(name) => {
            let idx = action_index(actions, name);
            code.push(Op::LoadConst(idx as f32));
            code.push(Op::CallNative(N_ACTION, 0));
        }
    }
    Ok(())
}

fn action_index(actions: &mut Vec<String>, name: &str) -> u8 {
    if let Some(i) = actions.iter().position(|s| s == name) {
        return i as u8;
    }
    actions.push(name.to_string());
    (actions.len() - 1) as u8
}

fn emit_expr(token: &str, code: &mut Vec<Op>) -> Result<(), CompileError> {
    let t = token.trim();
    if t == "vx" {
        code.push(Op::LoadGlobal(G_VX));
        return Ok(());
    }
    if t == "vy" {
        code.push(Op::LoadGlobal(G_VY));
        return Ok(());
    }
    if let Ok(n) = t.parse::<f32>() {
        code.push(Op::LoadConst(n));
        return Ok(());
    }
    Err(CompileError::Syntax(format!("bad expr: {t}")))
}

fn emit_set_velocity(line: &str, code: &mut Vec<Op>) -> Result<(), CompileError> {
    let inner = line
        .strip_prefix("set_velocity(")
        .and_then(|s| s.strip_suffix(')'))
        .ok_or_else(|| CompileError::Syntax("set_velocity(...)".into()))?;
    let parts: Vec<&str> = inner.split(',').map(|s| s.trim()).collect();
    if parts.len() != 2 {
        return Err(CompileError::Syntax("set_velocity needs 2 args".into()));
    }
    emit_expr(parts[0], code)?;
    emit_expr(parts[1], code)?;
    code.push(Op::CallNative(N_SET_VELOCITY, 2));
    Ok(())
}

fn emit_y_sub_dt(code: &mut Vec<Op>, line: &str) -> Result<(), CompileError> {
    let part = line
        .split("y = y -")
        .nth(1)
        .ok_or_else(|| CompileError::Syntax("expected y = y -".into()))?
        .trim();
    let tokens: Vec<&str> = part.split('*').map(|s| s.trim()).collect();
    if tokens.len() != 2 {
        return Err(CompileError::Syntax("expected N * dt".into()));
    }
    let n: f32 = tokens[0]
        .parse()
        .map_err(|_| CompileError::Syntax("bad number".into()))?;
    code.push(Op::LoadGlobal(G_Y));
    code.push(Op::LoadConst(n));
    code.push(Op::LoadGlobal(G_DT));
    code.push(Op::Mul);
    code.push(Op::Sub);
    code.push(Op::StoreGlobal(G_Y));
    Ok(())
}
