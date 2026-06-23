//! Заполнение Lynx Core [`SpriteBatch2D`] из Legacy [`Scene`] (M2).

use lynx_core::render::batch2d::{Batch2DSprite, SpriteBatch2D};

use crate::Scene;

/// Копирует видимые 2D-спрайты сцены в batch (мировые координаты = `world_pos_cache`).
pub fn scene_fill_batch2d(scene: &Scene, batch: &mut SpriteBatch2D, viewport_w: f32, viewport_h: f32) -> u32 {
    batch.set_viewport(viewport_w, viewport_h);
    let mut n = 0u32;
    for e in &scene.entities {
        if !e.visible {
            continue;
        }
        let cx = e.world_pos_cache.x + e.sprite.visual_offset.x;
        let cy = e.world_pos_cache.y + e.sprite.visual_offset.y;
        let draw_w = e
            .sprite
            .visual_width
            .unwrap_or(e.transform.size.x)
            .max(0.5);
        let draw_h = e
            .sprite
            .visual_height
            .unwrap_or(e.transform.size.y)
            .max(0.5);
        let uv = e.sprite.uv_rect.map(|r| [r.x, r.y, r.w, r.h]).unwrap_or([0.0, 0.0, 1.0, 1.0]);
        let sprite = Batch2DSprite {
            center_x: cx,
            center_y: cy,
            width: draw_w,
            height: draw_h,
            color_rgba: e.sprite.color_hex,
            uv,
            texture_id: 0,
            sorting_layer: e.sprite.sorting_layer,
            order_in_layer: e.sprite.order_in_layer,
            rot_deg: e.transform.rot,
        };
        if batch.push_sprite(sprite) {
            n += 1;
        }
    }
    n
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{Color, Vec2};

    #[test]
    fn fill_from_scene() {
        let mut scene = Scene::new();
        scene.add_entity("a", Vec2::new(100.0, 200.0), Color { r: 1.0, g: 0.0, b: 0.0, a: 1.0 });
        scene.propagate_transform_hierarchy();
        let mut batch = SpriteBatch2D::new(16);
        let n = scene_fill_batch2d(&scene, &mut batch, 800.0, 600.0);
        assert_eq!(n, 1);
        assert_eq!(batch.len(), 1);
    }
}
