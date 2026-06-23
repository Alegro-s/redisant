import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/engine_models.dart';

/// Подмешивает объекты autoload-сцен (Godot-style) в основную сцену Play.
Future<Scene> mergeAutoloadIntoScene({
  required String projectRoot,
  required Scene mainScene,
  required String mainSceneId,
  required List<String> autoloadSceneIds,
}) async {
  if (autoloadSceneIds.isEmpty) return mainScene;

  final mergedObjects = List<SceneObject>.from(mainScene.objects);
  for (final autoloadId in autoloadSceneIds) {
    if (autoloadId == mainSceneId) continue;
    final path = File(p.join(projectRoot, 'scenes', '$autoloadId.json'));
    if (!await path.exists()) continue;
    try {
      final raw = jsonDecode(await path.readAsString()) as Map<String, dynamic>;
      final auto = Scene.fromJson(raw);
      for (final o in auto.objects) {
        mergedObjects.add(
          o.copyWith(
            id: 'autoload_${autoloadId}_${o.id}',
            name: '[${autoloadId}] ${o.name}',
            properties: {
              ...o.properties,
              'lynxAutoload': autoloadId,
            },
          ),
        );
      }
    } catch (_) {}
  }
  return Scene(
    id: mainScene.id,
    name: mainScene.name,
    objects: mergedObjects,
    layers: mainScene.layers,
    camera: mainScene.camera,
    backgroundColorArgb: mainScene.backgroundColorArgb,
    physics: mainScene.physics,
    tilemaps: mainScene.tilemaps,
    rooms: mainScene.rooms,
    createdAt: mainScene.createdAt,
    modifiedAt: mainScene.modifiedAt,
    revision: mainScene.revision,
    cloudRevision: mainScene.cloudRevision,
    collaboration: mainScene.collaboration,
    extensions: mainScene.extensions,
  );
}
