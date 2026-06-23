//! Заготовка плагина Lynx 3D (волна 1: контракт; волна 6: native + рендер).

use super::{PluginCapability, PluginDescriptor};
use crate::Scene;
use std::collections::HashMap;

pub const LYNX_3D_PLUGIN_ID: &str = "lynx.3d";

pub fn descriptor() -> PluginDescriptor {
    PluginDescriptor {
        id: LYNX_3D_PLUGIN_ID,
        version: "0.1.0",
        capabilities: &[
            PluginCapability::Scene3d,
            PluginCapability::Render3d,
            PluginCapability::Physics3d,
            PluginCapability::EditorViewport3d,
        ],
    }
}

/// Хук после 2D `update`: парсит `extensions.lynx.3d` через Lynx Core (M3).
/// Рендер Play — Flutter Canvas; нативный forward — `lynx-m3-demo` / будущий Player viewport.
pub fn post_update_stub(
    _scene: &mut Scene,
    extensions: &HashMap<String, serde_json::Value>,
) {
    let Some(ext) = extensions.get(LYNX_3D_PLUGIN_ID) else {
        return;
    };
    if let Ok(parsed) = lynx_core::scene3d::parse_extension(ext) {
        if parsed.active {
            let _ = parsed.objects.len();
            let _ = parsed.room.as_ref();
        }
    }
}
