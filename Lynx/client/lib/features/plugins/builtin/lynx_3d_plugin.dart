import 'package:flutter/material.dart';

import '../lynx_3d/lynx_3d_codec.dart';
import '../lynx_plugin_contract.dart';
import '../lynx_plugin_capability.dart';
import '../lynx_plugin_manifest.dart';

/// Плагин 3D: viewport, экспорт объектов, Play overlay (волна 6).
final class Lynx3dClientPlugin extends LynxClientPlugin {
  @override
  LynxPluginManifest get manifest => const LynxPluginManifest(
        id: Lynx3dPluginIds.pluginId,
        name: 'Lynx 3D',
        version: '0.1.0',
        apiVersion: 1,
        description:
            '3D-сцены поверх Lynx 2D: extensions в сцене, свойства объектов.',
        capabilities: [
          LynxPluginCapability.scene3d,
          LynxPluginCapability.render3d,
          LynxPluginCapability.physics3d,
          LynxPluginCapability.editorViewport3d,
        ],
        sceneExtensionKey: Lynx3dPluginIds.sceneExtensionKey,
        objectPropertyKey: Lynx3dPluginIds.objectPropertyKey,
        optionalNativeLib: 'lynx_plugin_3d',
        builtinId: Lynx3dPluginIds.pluginId,
      );

  @override
  LynxSceneExportContribution contributeSceneExport({
    required Map<String, dynamic> editorSceneJson,
    required LynxPluginProjectContext ctx,
  }) {
    if (!ctx.plugins.enabled.contains(Lynx3dPluginIds.pluginId)) {
      return const LynxSceneExportContribution();
    }
    final existing =
        editorSceneJson['extensions'] as Map<String, dynamic>? ?? {};
    final prior = existing[Lynx3dPluginIds.sceneExtensionKey];
    final Map<String, dynamic> block;
    if (prior is Map) {
      block = Map<String, dynamic>.from(prior);
    } else {
      block = defaultSceneExtension(ctx);
    }
    block['active'] = true;
    block['objects'] = _collectObjects3d(editorSceneJson);
    block.putIfAbsent(
      'room',
      () => {
        'width': 8,
        'height': 4,
        'depth': 8,
        'center': [0, 2, 0],
      },
    );
    return LynxSceneExportContribution(
      extensions: {Lynx3dPluginIds.sceneExtensionKey: block},
      enabledPluginIds: const [Lynx3dPluginIds.pluginId],
    );
  }

  static Map<String, dynamic> defaultSceneExtension(LynxPluginProjectContext ctx) {
    final cfg = ctx.plugins.config[Lynx3dPluginIds.pluginId] ?? {};
    final cam = cfg['defaultCamera'] as String? ?? 'perspective';
    return {
      'active': true,
      'world': {
        'ambientColor': '#404050',
        'gravity': [0, -9.81, 0],
      },
      'camera': {
        'type': cam,
        'fovY': 60,
        'near': 0.1,
        'far': 500,
        'orbitDistance': 12,
      },
      'room': {
        'width': 8,
        'height': 4,
        'depth': 8,
        'center': [0, 2, 0],
      },
    };
  }

  static List<Map<String, dynamic>> _collectObjects3d(
    Map<String, dynamic> editorSceneJson,
  ) {
    final list = <Map<String, dynamic>>[];
    final objs = editorSceneJson['objects'] as List? ?? [];
    for (final raw in objs) {
      if (raw is! Map) continue;
      final props = raw['properties'] as Map?;
      final block = props?[Lynx3dPluginIds.objectPropertyKey];
      if (block is! Map) continue;
      final m = Map<String, dynamic>.from(block);
      m['id'] = raw['id'];
      list.add(m);
    }
    return list;
  }

  @override
  String? editorStatusChip(LynxPluginProjectContext ctx) {
    if (!ctx.plugins.enabled.contains(Lynx3dPluginIds.pluginId)) return null;
    return '3D';
  }

  @override
  List<Widget> buildEditorPanels(BuildContext context) {
    return const [
      ListTile(
        dense: true,
        leading: Icon(Icons.view_in_ar_outlined),
        title: Text('Lynx 3D'),
        subtitle: Text(
          'Вкладка «3D» в центре · GLB в инспекторе объекта · Play overlay.',
        ),
      ),
    ];
  }

  @override
  bool get wantsOverlayRenderPass => true;
}
