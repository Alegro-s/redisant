/// Стабильные capability id (контракт v1, см. PLUGIN_SYSTEM.md).
enum LynxPluginCapability {
  scene3d('scene.3d'),
  render3d('render.3d'),
  physics3d('physics.3d'),
  editorViewport3d('editor.viewport.3d'),
  exportHook('export.hook'),
  scriptHook('script.hook');

  const LynxPluginCapability(this.id);
  final String id;

  static LynxPluginCapability? tryParse(String raw) {
    for (final c in LynxPluginCapability.values) {
      if (c.id == raw) return c;
    }
    return null;
  }
}
