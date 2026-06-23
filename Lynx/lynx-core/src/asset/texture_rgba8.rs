//! M12a: загрузка albedo PNG (RGBA8) для tint base color в forward frame.

use std::path::Path;

#[derive(Clone, Debug)]
pub struct Rgba8Image {
    pub width: u32,
    pub height: u32,
    pub pixels: Vec<u8>,
}

pub fn load_rgba8_path(path: &Path) -> Result<Rgba8Image, String> {
    let img = image::open(path).map_err(|e| format!("texture open: {e}"))?;
    let rgba = img.to_rgba8();
    let (w, h) = rgba.dimensions();
    Ok(Rgba8Image {
        width: w,
        height: h,
        pixels: rgba.into_raw(),
    })
}

/// Средний RGB [0,1] — preview tint до GPU sampling (12b).
pub fn average_rgb(img: &Rgba8Image) -> [f32; 3] {
    if img.pixels.is_empty() {
        return [1.0, 1.0, 1.0];
    }
    let mut r = 0u64;
    let mut g = 0u64;
    let mut b = 0u64;
    let mut n = 0u64;
    for px in img.pixels.chunks_exact(4) {
        let a = px[3] as u64;
        if a == 0 {
            continue;
        }
        r += px[0] as u64;
        g += px[1] as u64;
        b += px[2] as u64;
        n += 1;
    }
    if n == 0 {
        return [1.0, 1.0, 1.0];
    }
    [
        (r as f32) / (n as f32) / 255.0,
        (g as f32) / (n as f32) / 255.0,
        (b as f32) / (n as f32) / 255.0,
    ]
}

pub fn tint_rgba(base: [f32; 4], rgb: [f32; 3]) -> [f32; 4] {
    [
        (base[0] * rgb[0]).clamp(0.0, 1.0),
        (base[1] * rgb[1]).clamp(0.0, 1.0),
        (base[2] * rgb[2]).clamp(0.0, 1.0),
        base[3],
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tint_white_by_red() {
        let out = tint_rgba([1.0, 1.0, 1.0, 1.0], [0.8, 0.1, 0.1]);
        assert!(out[0] > 0.7 && out[1] < 0.2);
    }
}
