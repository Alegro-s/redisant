//! CPU 2D sprite batch — quad list, sort keys, NDC vertices for PAL flush.

use crate::math::Vec2;
use crate::render::Color;

/// Один спрайт в батче (экранные пиксели, origin = центр).
#[derive(Clone, Copy, Debug)]
pub struct Batch2DSprite {
    pub center_x: f32,
    pub center_y: f32,
    pub width: f32,
    pub height: f32,
    pub color_rgba: u32,
    pub uv: [f32; 4],
    pub texture_id: u32,
    pub sorting_layer: i32,
    pub order_in_layer: i32,
    pub rot_deg: f32,
}

/// Вершина для D3D12 (совпадает с `shaders/batch2d.hlsl`).
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Batch2DVertex {
    pub pos: [f32; 2],
    pub col: [f32; 4],
}

const DEFAULT_CAP: usize = 4096;

pub struct SpriteBatch2D {
    sprites: Vec<Batch2DSprite>,
    viewport_w: f32,
    viewport_h: f32,
    capacity: usize,
}

impl Default for SpriteBatch2D {
    fn default() -> Self {
        Self::new(DEFAULT_CAP)
    }
}

impl SpriteBatch2D {
    pub fn new(capacity: usize) -> Self {
        Self {
            sprites: Vec::with_capacity(capacity.min(DEFAULT_CAP)),
            viewport_w: 1280.0,
            viewport_h: 720.0,
            capacity: capacity.max(1),
        }
    }

    pub fn set_viewport(&mut self, width: f32, height: f32) {
        self.viewport_w = width.max(1.0);
        self.viewport_h = height.max(1.0);
    }

    pub fn clear(&mut self) {
        self.sprites.clear();
    }

    pub fn len(&self) -> usize {
        self.sprites.len()
    }

    pub fn is_empty(&self) -> bool {
        self.sprites.is_empty()
    }

    pub fn push_sprite(&mut self, sprite: Batch2DSprite) -> bool {
        if self.sprites.len() >= self.capacity {
            return false;
        }
        self.sprites.push(sprite);
        true
    }

    /// Центр, размер, ARGB (`0xAARRGGBB` как в Legacy `color_hex`).
    pub fn push_center_rect(
        &mut self,
        center_x: f32,
        center_y: f32,
        width: f32,
        height: f32,
        color_rgba: u32,
    ) -> bool {
        self.push_sprite(Batch2DSprite {
            center_x,
            center_y,
            width: width.max(0.5),
            height: height.max(0.5),
            color_rgba,
            uv: [0.0, 0.0, 1.0, 1.0],
            texture_id: 0,
            sorting_layer: 0,
            order_in_layer: 0,
            rot_deg: 0.0,
        })
    }

    pub fn sort_draw_order(&mut self) {
        self.sprites.sort_by(|a, b| {
            a.sorting_layer
                .cmp(&b.sorting_layer)
                .then(a.order_in_layer.cmp(&b.order_in_layer))
                .then(a.texture_id.cmp(&b.texture_id))
        });
    }

    fn screen_to_ndc(&self, x: f32, y: f32) -> [f32; 2] {
        let ndc_x = (x / self.viewport_w) * 2.0 - 1.0;
        let ndc_y = 1.0 - (y / self.viewport_h) * 2.0;
        [ndc_x, ndc_y]
    }

    fn vertex_color(color_rgba: u32) -> [f32; 4] {
        let c = Color::from_rgba8(color_rgba);
        [c.r, c.g, c.b, c.a]
    }

    fn emit_quad(
        &self,
        out: &mut Vec<Batch2DVertex>,
        cx: f32,
        cy: f32,
        hw: f32,
        hh: f32,
        col: [f32; 4],
        rot_rad: f32,
    ) {
        let corners = [
            Vec2::new(-hw, -hh),
            Vec2::new(hw, -hh),
            Vec2::new(-hw, hh),
            Vec2::new(hw, hh),
        ];
        let (sin, cos) = rot_rad.sin_cos();
        let mut ndc = [[0.0f32; 2]; 4];
        for (i, c) in corners.iter().enumerate() {
            let rx = c.x * cos - c.y * sin;
            let ry = c.x * sin + c.y * cos;
            ndc[i] = self.screen_to_ndc(cx + rx, cy + ry);
        }
        // два треугольника: 0-1-2, 1-3-2
        let idx = [[0, 1, 2], [1, 3, 2]];
        for tri in idx {
            for &vi in &tri {
                out.push(Batch2DVertex {
                    pos: ndc[vi],
                    col,
                });
            }
        }
    }

    /// Собрать треугольный список для GPU flush.
    pub fn build_vertices(&mut self) -> Vec<Batch2DVertex> {
        self.sort_draw_order();
        let mut out = Vec::with_capacity(self.sprites.len() * 6);
        for s in &self.sprites {
            let col = Self::vertex_color(s.color_rgba);
            let hw = s.width * 0.5;
            let hh = s.height * 0.5;
            let rot = s.rot_deg.to_radians();
            self.emit_quad(&mut out, s.center_x, s.center_y, hw, hh, col, rot);
        }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn batch_push_and_vertices() {
        let mut b = SpriteBatch2D::new(8);
        b.set_viewport(100.0, 100.0);
        assert!(b.push_center_rect(50.0, 50.0, 20.0, 10.0, 0xFF_FF_00_80));
        assert_eq!(b.len(), 1);
        let v = b.build_vertices();
        assert_eq!(v.len(), 6);
    }

    #[test]
    fn batch_capacity() {
        let mut b = SpriteBatch2D::new(1);
        assert!(b.push_center_rect(0.0, 0.0, 10.0, 10.0, 0xFF_FF_FF_FF));
        assert!(!b.push_center_rect(1.0, 1.0, 10.0, 10.0, 0xFF_FF_FF_FF));
    }
}
