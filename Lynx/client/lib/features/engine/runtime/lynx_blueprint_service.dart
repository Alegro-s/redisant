import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';
import '../widgets/lynx_blueprint_editor_dialog.dart';
import 'lynx_graph_compiler.dart';
import 'lynx_graph_model.dart';

String lynxGraphSidecarRelPath(String assetRelPath) => '$assetRelPath.graph.json';

Future<LynxGraphDocument?> loadGraphSidecar(ProjectManager manager, ProjectAsset asset) async {
  final root = manager.rootPath;
  if (root == null) return null;
  final sidecar = File('$root/${lynxGraphSidecarRelPath(asset.path)}');
  if (await sidecar.exists()) {
    return lynxGraphFromJsonString(await sidecar.readAsString());
  }
  return null;
}

Future<void> saveBlueprintForScriptAsset(
  ProjectManager manager,
  ProjectAsset asset,
  LynxGraphDocument doc,
) async {
  final root = manager.rootPath;
  if (root == null || manager.isCloudReadOnly) {
    throw StateError('read-only or no project root');
  }
  final compiled = compileLynxGraphToScript(doc);
  final scriptFile = File('$root/${asset.path}');
  await scriptFile.parent.create(recursive: true);
  await scriptFile.writeAsString(compiled);
  final graphFile = File('$root/${lynxGraphSidecarRelPath(asset.path)}');
  await graphFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(doc.toJson()),
  );

  final idx = manager.assets.indexWhere((a) => a.id == asset.id);
  if (idx >= 0) {
    manager.updateScriptAssetContent(asset.id, compiled);
  }
  if (manager.canPushCloudAsset) {
    await manager.syncLocalAssetBytesToCloud(
      asset.id,
      Uint8List.fromList(utf8.encode(compiled)),
    );
  }
}

Future<bool> openBlueprintEditorForScript(
  BuildContext context,
  ProjectManager manager,
  ProjectAsset asset, {
  VoidCallback? onSaved,
}) async {
  if (manager.isCloudReadOnly) return false;
  var initial = await loadGraphSidecar(manager, asset);
  initial ??= LynxGraphDocument.defaultPlayerController();
  if (!context.mounted) return false;
  final result = await showLynxBlueprintEditor(context, initial: initial);
  if (result == null || !context.mounted) return false;
  try {
    await saveBlueprintForScriptAsset(manager, asset, result);
    onSaved?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blueprint сохранён → LynxScript')),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blueprint: $e')),
      );
    }
    return false;
  }
}
