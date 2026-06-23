//! TIC-80 compatible Lua API (`spr`, `map`, `pix`, `btn`, …) on logic grids.

use std::cell::Cell;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

#[cfg(feature = "legacy_lua")]
use mlua::{Lua, MultiValue, Value};

use crate::input_frame::InputFrame;
use crate::LogicGrid;

thread_local! {
    static GRIDS_TLS: Cell<*mut HashMap<String, LogicGrid>> = const { Cell::new(std::ptr::null_mut()) };
    static FRAME_TLS: Cell<Option<InputFrame>> = const { Cell::new(None) };
}

/// Bind per-tick grids + input for persistent TIC() VMs.
pub fn bind_runtime(grids_ptr: *mut HashMap<String, LogicGrid>, frame: InputFrame) {
    GRIDS_TLS.with(|c| c.set(grids_ptr));
    FRAME_TLS.with(|c| c.set(Some(frame)));
}

fn with_grids_mut<R>(grids_ptr: *mut HashMap<String, LogicGrid>, f: impl FnOnce(&mut HashMap<String, LogicGrid>) -> R) -> R {
    let ptr = GRIDS_TLS.with(|c| c.get());
    let p = if !ptr.is_null() { ptr } else { grids_ptr };
    unsafe { f(&mut *p) }
}

fn with_grids<R>(grids_ptr: *mut HashMap<String, LogicGrid>, f: impl FnOnce(&HashMap<String, LogicGrid>) -> R) -> R {
    let ptr = GRIDS_TLS.with(|c| c.get());
    let p = if !ptr.is_null() { ptr } else { grids_ptr };
    unsafe { f(&*p) }
}

fn current_frame(fallback: InputFrame) -> InputFrame {
    FRAME_TLS.with(|c| c.get()).unwrap_or(fallback)
}

pub const TIC_DISPLAY_W: u32 = 240;
pub const TIC_DISPLAY_H: u32 = 136;
pub const TIC_BANK_W: u32 = 128;
pub const TIC_BANK_H: u32 = 128;
pub const TIC_MAP_W: u32 = 240;
pub const TIC_MAP_H: u32 = 136;
pub const TIC_SPRITE_SIZE: i32 = 8;

pub fn ensure_tic_grids(grids: &mut HashMap<String, LogicGrid>) {
    grids
        .entry("display".into())
        .or_insert_with(|| LogicGrid::ensure_size(TIC_DISPLAY_W, TIC_DISPLAY_H));
    grids
        .entry("tic_bank".into())
        .or_insert_with(|| LogicGrid::ensure_size(TIC_BANK_W, TIC_BANK_H));
    grids
        .entry("tic_map".into())
        .or_insert_with(|| LogicGrid::ensure_size(TIC_MAP_W, TIC_MAP_H));
}

fn grid_get(grids: &HashMap<String, LogicGrid>, name: &str, x: i32, y: i32) -> i32 {
    grids.get(name).map(|g| g.get_cell(x, y)).unwrap_or(0)
}

fn grid_set(grids: &mut HashMap<String, LogicGrid>, name: &str, x: i32, y: i32, v: i32) {
    if let Some(g) = grids.get_mut(name) {
        g.set_cell(x, y, v);
    }
}

fn tic_btn_held(frame: &InputFrame, id: i32) -> bool {
    match id {
        0 => frame.key_held("LEFT"),
        1 => frame.key_held("RIGHT"),
        2 => frame.key_held("UP"),
        3 => frame.key_held("DOWN"),
        4 => frame.keys.space || frame.gp.face_a,
        5 => frame.gp.face_b,
        6 => frame.key_held("X"),
        7 => frame.key_held("Z"),
        _ => false,
    }
}

fn tic_btn_pressed(frame: &InputFrame, id: i32) -> bool {
    match id {
        0 => frame.key_pressed("LEFT"),
        1 => frame.key_pressed("RIGHT"),
        2 => frame.key_pressed("UP"),
        3 => frame.key_pressed("DOWN"),
        4 => frame.key_pressed("SPACE") || (frame.gp.face_a && !frame.gp_prev.face_a),
        5 => frame.gp.face_b && !frame.gp_prev.face_b,
        6 => frame.key_pressed("X"),
        7 => frame.key_pressed("Z"),
        _ => false,
    }
}

fn blit_sprite(
    grids: &mut HashMap<String, LogicGrid>,
    id: i32,
    dx: i32,
    dy: i32,
    sw: i32,
    sh: i32,
    scale: i32,
    flip: i32,
    chroma: i32,
) {
    let scale = scale.max(1);
    let col = id.rem_euclid(16);
    let row = id.div_euclid(16);
    let sx0 = col * TIC_SPRITE_SIZE;
    let sy0 = row * TIC_SPRITE_SIZE;
    for py in 0..sh * scale {
        for px in 0..sw * scale {
            let mut bx = sx0 + px / scale;
            let mut by = sy0 + py / scale;
            if flip & 1 != 0 {
                bx = sx0 + sw - 1 - px / scale;
            }
            if flip & 2 != 0 {
                by = sy0 + sh - 1 - py / scale;
            }
            let c = grid_get(grids, "tic_bank", bx, by);
            if c == 0 || (chroma >= 0 && c == chroma) {
                continue;
            }
            grid_set(grids, "display", dx + px, dy + py, c);
        }
    }
}

fn draw_map_region(
    grids: &mut HashMap<String, LogicGrid>,
    mx: i32,
    my: i32,
    mw: i32,
    mh: i32,
    sx: i32,
    sy: i32,
    scale: i32,
) {
    let scale = scale.max(1);
    for ty in 0..mh {
        for tx in 0..mw {
            let tile = grid_get(grids, "tic_map", mx + tx, my + ty);
            if tile <= 0 {
                continue;
            }
            blit_sprite(
                grids,
                tile,
                sx + tx * TIC_SPRITE_SIZE * scale,
                sy + ty * TIC_SPRITE_SIZE * scale,
                TIC_SPRITE_SIZE,
                TIC_SPRITE_SIZE,
                scale,
                0,
                -1,
            );
        }
    }
}

#[cfg(feature = "legacy_lua")]
pub fn register_tic_lua_globals(
    lua: &Lua,
    grids_ptr: *mut HashMap<String, LogicGrid>,
    frame: InputFrame,
    sound_q: Arc<Mutex<Vec<String>>>,
) {
    unsafe {
        with_grids_mut(grids_ptr, ensure_tic_grids);
    }

    let grids_for_cls = grids_ptr;

    let cls = lua
        .create_function(move |_, color: Option<i32>| {
            with_grids_mut(grids_for_cls, |grids| {
                ensure_tic_grids(grids);
                if let Some(g) = grids.get_mut("display") {
                    g.fill(color.unwrap_or(0));
                }
            });
            Ok(())
        })
        .unwrap();
    lua.globals().set("cls", cls).unwrap();

    let pix = lua
        .create_function(move |_, args: MultiValue| {
            let v: Vec<Value> = args.into_vec();
            let x = v.first().and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let y = v.get(1).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            if v.len() >= 3 {
                let c = v[2].as_integer().unwrap_or(0) as i32;
                with_grids_mut(grids_ptr, |grids| grid_set(grids, "display", x, y, c));
                Ok(Value::Nil)
            } else {
                Ok(Value::Integer(
                    with_grids(grids_ptr, |grids| grid_get(grids, "display", x, y)) as i64,
                ))
            }
        })
        .unwrap();
    lua.globals().set("pix", pix).unwrap();

    let spr = lua
        .create_function(move |_, args: MultiValue| {
            let v: Vec<Value> = args.into_vec();
            let id = v.first().and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let x = v.get(1).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let y = v.get(2).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let chroma = v.get(3).and_then(|a| a.as_integer()).map(|c| c as i32);
            let sw = v
                .get(6)
                .and_then(|a| a.as_integer())
                .unwrap_or(TIC_SPRITE_SIZE as i64) as i32;
            let sh = v
                .get(7)
                .and_then(|a| a.as_integer())
                .unwrap_or(TIC_SPRITE_SIZE as i64) as i32;
            let scale = v.get(8).and_then(|a| a.as_integer()).unwrap_or(1) as i32;
            let flip = v.get(9).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            unsafe {
                with_grids_mut(grids_ptr, |grids| {
                    blit_sprite(
                        grids,
                        id,
                        x,
                        y,
                        sw,
                        sh,
                        scale,
                        flip,
                        chroma.unwrap_or(-1),
                    );
                });
            }
            Ok(())
        })
        .unwrap();
    lua.globals().set("spr", spr).unwrap();

    let map_fn = lua
        .create_function(move |_, args: MultiValue| {
            let v: Vec<Value> = args.into_vec();
            let mx = v.first().and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let my = v.get(1).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let mw = v.get(2).and_then(|a| a.as_integer()).unwrap_or(TIC_MAP_W as i64) as i32;
            let mh = v.get(3).and_then(|a| a.as_integer()).unwrap_or(TIC_MAP_H as i64) as i32;
            let sx = v.get(4).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let sy = v.get(5).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let scale = v.get(6).and_then(|a| a.as_integer()).unwrap_or(1) as i32;
            with_grids_mut(grids_ptr, |grids| {
                draw_map_region(grids, mx, my, mw, mh, sx, sy, scale);
            });
            Ok(())
        })
        .unwrap();
    lua.globals().set("map", map_fn).unwrap();

    let btn = lua
        .create_function(move |_, id: i32| {
            Ok(tic_btn_held(&current_frame(frame), id))
        })
        .unwrap();
    lua.globals().set("btn", btn).unwrap();

    let btnp = lua
        .create_function(move |_, id: i32| {
            Ok(tic_btn_pressed(&current_frame(frame), id))
        })
        .unwrap();
    lua.globals().set("btnp", btnp).unwrap();

    let sound_q_sfx = sound_q.clone();
    let sfx = lua
        .create_function(move |_, args: MultiValue| {
            let v: Vec<Value> = args.into_vec();
            let id = v.first().and_then(|a| a.as_integer()).unwrap_or(0);
            let note = v.get(1).and_then(|a| a.as_integer()).unwrap_or(-1);
            let duration = v.get(2).and_then(|a| a.as_integer()).unwrap_or(-1);
            let channel = v.get(3).and_then(|a| a.as_integer()).unwrap_or(-1);
            let volume = v.get(4).and_then(|a| a.as_integer()).unwrap_or(15);
            let speed = v.get(5).and_then(|a| a.as_integer()).unwrap_or(0);
            let line = format!(
                r#"{{"tic_sfx":{{"id":{id},"note":{note},"duration":{duration},"channel":{channel},"volume":{volume},"speed":{speed}}}}}"#
            );
            let mut q = sound_q_sfx.lock().unwrap();
            q.push(line);
            Ok(())
        })
        .unwrap();
    lua.globals().set("sfx", sfx).unwrap();

    let sound_q_music = sound_q.clone();
    let music = lua
        .create_function(move |_, args: MultiValue| {
            let v: Vec<Value> = args.into_vec();
            let track = v.first().and_then(|a| a.as_integer()).unwrap_or(-1);
            let frame = v.get(1).and_then(|a| a.as_integer()).unwrap_or(-1);
            let row = v.get(2).and_then(|a| a.as_integer()).unwrap_or(-1);
            let loop_on = v.get(3).and_then(|a| a.as_boolean()).unwrap_or(true);
            let line = format!(
                r#"{{"tic_music":{{"track":{track},"frame":{frame},"row":{row},"loop":{loop_on}}}}}"#
            );
            let mut q = sound_q_music.lock().unwrap();
            q.push(line);
            Ok(())
        })
        .unwrap();
    lua.globals().set("music", music).unwrap();

    let print_fn = lua
        .create_function(move |_, args: MultiValue| {
            let v: Vec<Value> = args.into_vec();
            let text = v
                .first()
                .map(|a| a.to_string().unwrap_or_default())
                .unwrap_or_default();
            let x = v.get(1).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let y = v.get(2).and_then(|a| a.as_integer()).unwrap_or(0) as i32;
            let color = v.get(3).and_then(|a| a.as_integer()).unwrap_or(15) as i32;
            unsafe {
                with_grids_mut(grids_ptr, |grids| draw_tic_text(grids, &text, x, y, color));
            }
            Ok(())
        })
        .unwrap();
    lua.globals().set("print", print_fn).unwrap();
}

fn draw_tic_text(grids: &mut HashMap<String, LogicGrid>, text: &str, x: i32, y: i32, color: i32) {
    let mut cx = x;
    for ch in text.chars() {
        if ch == '\n' {
            continue;
        }
        draw_char(grids, ch, cx, y, color);
        cx += 6;
    }
}

fn draw_char(grids: &mut HashMap<String, LogicGrid>, ch: char, x: i32, y: i32, color: i32) {
    let glyph = tic_font_glyph(ch);
    for (row, bits) in glyph.iter().enumerate() {
        for col in 0..5 {
            if bits & (1 << (4 - col)) != 0 {
                grid_set(grids, "display", x + col as i32, y + row as i32, color);
            }
        }
    }
}

fn tic_font_glyph(ch: char) -> [u8; 6] {
    match ch {
        '0' => [0x0E, 0x11, 0x13, 0x15, 0x11, 0x0E],
        '1' => [0x04, 0x0C, 0x04, 0x04, 0x04, 0x0E],
        '2' => [0x0E, 0x11, 0x02, 0x04, 0x08, 0x1F],
        '3' => [0x1F, 0x02, 0x04, 0x02, 0x11, 0x0E],
        '4' => [0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02],
        '5' => [0x1F, 0x10, 0x1E, 0x01, 0x11, 0x0E],
        '6' => [0x06, 0x08, 0x10, 0x1E, 0x11, 0x0E],
        '7' => [0x1F, 0x01, 0x02, 0x04, 0x08, 0x08],
        '8' => [0x0E, 0x11, 0x0E, 0x11, 0x11, 0x0E],
        '9' => [0x0E, 0x11, 0x0F, 0x01, 0x02, 0x0C],
        'A'..='Z' => [0x0E, 0x11, 0x11, 0x1F, 0x11, 0x11],
        'a'..='z' => [0x00, 0x00, 0x0E, 0x01, 0x0F, 0x11],
        ' ' => [0; 6],
        '!' => [0x04, 0x04, 0x04, 0x04, 0x00, 0x04],
        ':' => [0x00, 0x04, 0x00, 0x04, 0x00, 0x00],
        '-' => [0x00, 0x00, 0x0E, 0x00, 0x00, 0x00],
        '+' => [0x00, 0x04, 0x0E, 0x04, 0x00, 0x00],
        _ => [0x1F, 0x11, 0x15, 0x15, 0x11, 0x1F],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ensure_tic_grids_sizes() {
        let mut g = HashMap::new();
        ensure_tic_grids(&mut g);
        assert_eq!(g["display"].w, TIC_DISPLAY_W);
        assert_eq!(g["tic_bank"].w, TIC_BANK_W);
    }
}
