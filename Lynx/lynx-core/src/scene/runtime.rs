//! SceneManager hooks (M5c): load / push / pop без Lua.

#[derive(Clone, Debug, Default)]
pub struct SceneRuntime {
    pub pending_load: Option<String>,
    pub scene_stack: Vec<String>,
}

impl SceneRuntime {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn load_scene(&mut self, scene_id: impl Into<String>) {
        self.pending_load = Some(scene_id.into());
    }

    pub fn push_scene(&mut self, scene_id: impl Into<String>) {
        let id = scene_id.into();
        self.scene_stack.push(id.clone());
        self.pending_load = Some(id);
    }

    pub fn pop_scene(&mut self) -> bool {
        if let Some(id) = self.scene_stack.pop() {
            self.pending_load = Some(id);
            true
        } else {
            false
        }
    }

    pub fn take_pending_load(&mut self) -> Option<String> {
        self.pending_load.take()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn load_push_pop() {
        let mut rt = SceneRuntime::new();
        rt.load_scene("main");
        assert_eq!(rt.take_pending_load().as_deref(), Some("main"));
        rt.push_scene("level2");
        assert_eq!(rt.take_pending_load().as_deref(), Some("level2"));
        assert!(rt.pop_scene());
        assert_eq!(rt.take_pending_load().as_deref(), Some("level2"));
    }
}
