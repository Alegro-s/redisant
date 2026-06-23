import 'package:flutter/widgets.dart';

import '../engine/models/engine_models.dart';
import 'lynx_plugin_contract.dart';
import 'lynx_plugin_manifest.dart';
import 'lynx_plugin_registry.dart';

/// Жизненный цикл плагинов для открытого проекта.
class LynxPluginHost {
  LynxPluginHost._();

  static final LynxPluginHost instance = LynxPluginHost._();

  LynxPluginProjectContext? _ctx;
  List<LynxClientPlugin> _active = const [];

  LynxPluginProjectContext? get context => _ctx;
  List<LynxClientPlugin> get activePlugins => _active;

  bool get is3dActive =>
      _active.any((p) => p.manifest.id == Lynx3dPluginIds.pluginId);

  Future<void> openProject(LynxPluginProjectContext ctx) async {
    await closeProject();
    LynxPluginRegistry.instance.ensureInitialized();
    await LynxPluginRegistry.instance.discoverProjectPlugins(ctx.projectRoot);
    _ctx = ctx;
    _active = LynxPluginRegistry.instance.resolveEnabled(ctx.plugins);
    for (final p in _active) {
      await p.onProjectOpened(ctx);
    }
  }

  Future<void> closeProject() async {
    for (final p in _active) {
      await p.onProjectClosed();
    }
    _active = const [];
    _ctx = null;
  }

  /// Все известные манифесты (builtin + найденные в `{project}/plugins`).
  List<LynxPluginManifest> availableManifests() {
    LynxPluginRegistry.instance.ensureInitialized();
    final list = LynxPluginRegistry.instance.allManifests.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// Подмешивает блоки `extensions` от активных плагинов в сцену редактора.
  void applySceneExtensions(Scene scene) {
    final ctx = _ctx;
    if (ctx == null || _active.isEmpty) return;
    final merge = mergeSceneExport(scene.toJson());
    if (merge.extensions.isEmpty) return;
    final ext = Map<String, dynamic>.from(scene.extensions);
    for (final e in merge.extensions.entries) {
      ext.putIfAbsent(
        e.key,
        () => e.value is Map
            ? Map<String, dynamic>.from(e.value as Map)
            : e.value,
      );
    }
    scene.extensions = ext;
  }

  LynxSceneExportContribution mergeSceneExport(
    Map<String, dynamic> editorSceneJson,
  ) {
    final ctx = _ctx;
    if (ctx == null || _active.isEmpty) {
      return const LynxSceneExportContribution();
    }
    final extensions = <String, dynamic>{};
    final existing =
        editorSceneJson['extensions'] as Map<String, dynamic>? ?? {};
    extensions.addAll(existing);
    var enabledIds = List<String>.from(ctx.plugins.enabled);
    for (final p in _active) {
      final c = p.contributeSceneExport(
        editorSceneJson: editorSceneJson,
        ctx: ctx,
      );
      extensions.addAll(c.extensions);
      for (final id in c.enabledPluginIds) {
        if (!enabledIds.contains(id)) enabledIds.add(id);
      }
    }
    return LynxSceneExportContribution(
      extensions: extensions,
      enabledPluginIds: enabledIds,
    );
  }

  List<String> editorStatusChips() {
    final ctx = _ctx;
    if (ctx == null) return const [];
    final chips = <String>[
      if (ctx.projectMode == LynxProjectMode.d3) 'режим 3D',
      if (ctx.projectMode == LynxProjectMode.hybrid) 'hybrid',
    ];
    for (final p in _active) {
      final c = p.editorStatusChip(ctx);
      if (c != null) chips.add(c);
    }
    return chips;
  }

  List<Widget> buildEditorPanels(BuildContext context) {
    final panels = <Widget>[];
    for (final p in _active) {
      panels.addAll(p.buildEditorPanels(context));
    }
    return panels;
  }
}
