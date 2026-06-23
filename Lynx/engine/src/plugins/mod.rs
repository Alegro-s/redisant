//! Расширяемость Lynx без 3D/ECS в ядре: реестр возможностей и хуки плагинов.

mod lynx_3d;

use serde::{Deserialize, Serialize};
use std::collections::HashSet;

pub use lynx_3d::LYNX_3D_PLUGIN_ID;

/// Стабильные идентификаторы возможностей (контракт v1).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PluginCapability {
    Scene3d,
    Render3d,
    Physics3d,
    EditorViewport3d,
    ExportHook,
    ScriptHook,
}

impl PluginCapability {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Scene3d => "scene.3d",
            Self::Render3d => "render.3d",
            Self::Physics3d => "physics.3d",
            Self::EditorViewport3d => "editor.viewport.3d",
            Self::ExportHook => "export.hook",
            Self::ScriptHook => "script.hook",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        Some(match s {
            "scene.3d" => Self::Scene3d,
            "render.3d" => Self::Render3d,
            "physics.3d" => Self::Physics3d,
            "editor.viewport.3d" => Self::EditorViewport3d,
            "export.hook" => Self::ExportHook,
            "script.hook" => Self::ScriptHook,
            _ => return None,
        })
    }
}

#[derive(Clone, Debug)]
pub struct PluginDescriptor {
    pub id: &'static str,
    pub version: &'static str,
    pub capabilities: &'static [PluginCapability],
}

impl PluginDescriptor {
    pub fn has(&self, cap: PluginCapability) -> bool {
        self.capabilities.contains(&cap)
    }
}

/// Реестр подключённых плагинов для одного процесса / сцены.
#[derive(Clone, Debug, Default)]
pub struct PluginRegistry {
    enabled_ids: Vec<String>,
    caps: HashSet<PluginCapability>,
}

impl PluginRegistry {
    pub fn with_builtin_stubs() -> Self {
        let mut reg = Self::default();
        reg.register_builtin(lynx_3d::descriptor());
        reg
    }

    fn register_builtin(&mut self, desc: PluginDescriptor) {
        for &c in desc.capabilities {
            self.caps.insert(c);
        }
    }

    /// Активировать плагины по id из `project.json` (`lynxPlugins.enabled`).
    pub fn set_enabled_ids(&mut self, ids: &[String]) {
        self.enabled_ids = ids.to_vec();
    }

    pub fn enabled_ids(&self) -> &[String] {
        &self.enabled_ids
    }

    pub fn is_enabled(&self, plugin_id: &str) -> bool {
        self.enabled_ids.iter().any(|id| id == plugin_id)
    }

    pub fn has_capability(&self, cap: PluginCapability) -> bool {
        if !self.caps.contains(&cap) {
            return false;
        }
        match cap {
            PluginCapability::Scene3d
            | PluginCapability::Render3d
            | PluginCapability::Physics3d
            | PluginCapability::EditorViewport3d => self.is_enabled(LYNX_3D_PLUGIN_ID),
            PluginCapability::ExportHook | PluginCapability::ScriptHook => false,
        }
    }

    /// Вызывается в конце `Scene::update`, когда включены соответствующие плагины.
    pub fn run_post_update_hooks(
        &self,
        scene: &mut crate::Scene,
        extensions: &std::collections::HashMap<String, serde_json::Value>,
    ) {
        if self.is_enabled(LYNX_3D_PLUGIN_ID) {
            lynx_3d::post_update_stub(scene, extensions);
        }
    }
}
