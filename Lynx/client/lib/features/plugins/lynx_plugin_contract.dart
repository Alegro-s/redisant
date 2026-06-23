import 'package:flutter/material.dart';

import 'lynx_plugin_capability.dart';
import 'lynx_plugin_manifest.dart';

/// Контекст открытого проекта для плагина.
class LynxPluginProjectContext {
  const LynxPluginProjectContext({
    required this.projectRoot,
    required this.projectMode,
    required this.plugins,
    this.displayName = '',
  });

  final String? projectRoot;
  final LynxProjectMode projectMode;
  final LynxProjectPlugins plugins;
  final String displayName;
}

/// Вклад плагина в экспорт сцены для Rust / Play.
class LynxSceneExportContribution {
  const LynxSceneExportContribution({
    this.extensions = const {},
    this.enabledPluginIds = const [],
  });

  final Map<String, dynamic> extensions;
  final List<String> enabledPluginIds;
}

/// Контракт клиентского плагина (редактор + рантайм).
abstract base class LynxClientPlugin {
  LynxPluginManifest get manifest;

  /// Вызывается при открытии проекта, если плагин в `lynxPlugins.enabled`.
  Future<void> onProjectOpened(LynxPluginProjectContext ctx) async {}

  Future<void> onProjectClosed() async {}

  /// Дополнения к JSON сцены перед `scene_from_json`.
  LynxSceneExportContribution contributeSceneExport({
    required Map<String, dynamic> editorSceneJson,
    required LynxPluginProjectContext ctx,
  }) {
    return const LynxSceneExportContribution();
  }

  /// Виджеты панели редактора (волна 6 — 3D viewport).
  List<Widget> buildEditorPanels(BuildContext context) => const [];

  /// Строка статуса в шапке редактора.
  String? editorStatusChip(LynxPluginProjectContext ctx) => null;

  /// Play: нужен отдельный слой отрисовки (3D поверх 2D).
  bool get wantsOverlayRenderPass => false;
}
