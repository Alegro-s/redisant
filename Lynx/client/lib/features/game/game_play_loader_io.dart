import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../engine/models/engine_models.dart';
import '../engine/runtime/nexus_play_snapshot.dart';
import '../engine/runtime/engine_version_gate.dart';
import '../engine/runtime/scene_autoload_merge.dart';
import '../engine/runtime/scene_to_engine_json.dart';
import '../engine/runtime/scene_ui_codec.dart';
import '../plugins/lynx_3d/lynx_3d_codec.dart';
import '../plugins/lynx_plugin_manifest.dart';

class PlayLoadResult {
  final String? error;
  final String? rustSceneJson;
  final Map<String, dynamic> playBootstrap;
  final String sceneId;
  final String? cartLuaScript;
  final bool useCartRuntime;
  const PlayLoadResult({
    this.error,
    this.rustSceneJson,
    this.playBootstrap = const {},
    this.sceneId = 'main',
    this.cartLuaScript,
    this.useCartRuntime = false,
  });
}

String _stripRustScene(Map<String, dynamic> sceneMap) {
  final out = <String, dynamic>{
    'entities': sceneMap['entities'],
    'next_id': sceneMap['next_id'] ?? 0,
  };
  for (final k in [
    'tilemaps',
    'rooms',
    'cameras',
    'camera_center',
    'audio_mixer',
    'logic_grids',
  ]) {
    if (sceneMap[k] != null) {
      out[k] = sceneMap[k];
    }
  }
  return jsonEncode(out);
}

Map<String, dynamic> _defaultBootstrap(GameProject? gp) {
  final dw = gp?.designWidth ?? 1280;
  final dh = gp?.designHeight ?? 720;
  return {
    'designWidth': dw,
    'designHeight': dh,
    'camera': {'x': dw / 2, 'y': dh / 2, 'zoom': 1.0},
    if (gp?.inputMap.isNotEmpty ?? false) 'inputMap': gp!.inputMap,
    'tilesets': _tilesetsJson(gp),
  };
}

List<Map<String, dynamic>> _tilesetsJson(GameProject? gp) {
  return gp?.tilesets.map((t) => t.toJson()).toList() ?? const [];
}

Future<PlayLoadResult> loadPlayPayload(
  String? projectPath, {
  bool freshPlay = false,
  String? sceneIdOverride,
}) async {
  if (projectPath == null || projectPath.isEmpty) {
    return const PlayLoadResult(error: 'Не указан путь к проекту');
  }
  final root = projectPath;
  if (!Directory(root).existsSync()) {
    return const PlayLoadResult(error: 'Папка проекта не найдена');
  }

  GameProject? gp;
  final pj = File(p.join(root, 'project.json'));
  if (await pj.exists()) {
    try {
      gp = GameProject.fromJson(jsonDecode(await pj.readAsString()) as Map<String, dynamic>);
    } catch (_) {}
  }
  final versionCheck = await checkProjectRuntimeVersions(
    minNexusEngineVersion: gp?.minNexusEngineVersion,
    minLynxCoreVersion: gp?.minLynxCoreVersion,
  );
  if (!versionCheck.ok) {
    return PlayLoadResult(error: versionCheck.message, sceneId: sceneIdOverride ?? 'main');
  }

  final sceneId = sceneIdOverride ?? gp?.startupSceneId ?? 'main';
  final sceneFile = File(p.join(root, 'scenes', '$sceneId.json'));
  if (!await sceneFile.exists()) {
    return PlayLoadResult(error: 'Нет сцены scenes/$sceneId.json', sceneId: sceneId);
  }
  var scene = Scene.fromJson(jsonDecode(await sceneFile.readAsString()) as Map<String, dynamic>);
  scene = await mergeAutoloadIntoScene(
    projectRoot: root,
    mainScene: scene,
    mainSceneId: sceneId,
    autoloadSceneIds: gp?.autoloadSceneIds ?? const [],
  );

  if (!freshPlay) {
    final fromSnap = await NexusPlaySnapshot.loadEngineJsonOrNull(root);
    if (fromSnap != null && fromSnap.isNotEmpty) {
      try {
        final snapRoot = jsonDecode(fromSnap) as Map<String, dynamic>;
        final rust = _stripRustScene(snapRoot);
        final runtime = snapRoot['runtime'] as Map<String, dynamic>?;
        final boot = <String, dynamic>{
          ..._defaultBootstrap(gp),
          if (runtime != null) ...runtime,
        };
        boot['tilesets'] = _tilesetsJson(gp);
        boot['uiWidgets'] = buildUiWidgetsFromScene(
          scene,
          designWidth: (gp?.designWidth ?? 1280).toDouble(),
          designHeight: (gp?.designHeight ?? 720).toDouble(),
        );
        final l3d = lynx3dPlayBootstrapFromScene(
          scene,
          windows3dRuntime: gp?.windows3dRuntime,
          projectMode: gp?.projectMode ?? LynxProjectMode.d2,
          plugin3dEnabled: gp?.lynxPlugins.is3dEnabled ?? false,
        );
        if (l3d != null) {
          boot['lynx3d'] = l3d;
        } else {
          boot.remove('lynx3d');
        }
        return PlayLoadResult(
          rustSceneJson: rust,
          playBootstrap: boot,
          sceneId: sceneId,
        );
      } catch (_) {
        
      }
    }
  }

  final assets = <ProjectAsset>[];
  final assetsDir = Directory(p.join(root, 'assets'));
  if (await assetsDir.exists()) {
    await for (final entity in assetsDir.list(recursive: true)) {
      if (entity is! File) continue;
      final base = p.basename(entity.path);
      if (base.endsWith('.meta.json')) continue;
      final rel = p.relative(entity.path, from: root);
      final ext = p.extension(entity.path).toLowerCase();
      String type;
      if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
        type = 'sprite';
      } else if (ext == '.lua') {
        type = 'script';
      } else {
        continue;
      }
      assets.add(ProjectAsset(
        id: rel.replaceAll('/', '_').replaceAll('\\', '_'),
        name: base,
        type: type,
        path: rel,
        createdAt: await entity.lastAccessed(),
        modifiedAt: await entity.lastModified(),
      ));
    }
  }

  final json = await buildEngineRuntimeSceneJson(
    scene: scene,
    projectRoot: root,
    assets: assets,
    project: gp,
    playSceneId: sceneId,
  );
  final map = jsonDecode(json) as Map<String, dynamic>;
  final rust = _stripRustScene(map);
  final boot = <String, dynamic>{
    ..._defaultBootstrap(gp),
    if (map['runtime'] is Map) ...(map['runtime'] as Map).cast<String, dynamic>(),
  };
  boot['tilesets'] = _tilesetsJson(gp);
  boot['uiWidgets'] = buildUiWidgetsFromScene(
    scene,
    designWidth: (gp?.designWidth ?? 1280).toDouble(),
    designHeight: (gp?.designHeight ?? 720).toDouble(),
  );
  final l3d = lynx3dPlayBootstrapFromScene(
    scene,
    windows3dRuntime: gp?.windows3dRuntime,
    projectMode: gp?.projectMode ?? LynxProjectMode.d2,
    plugin3dEnabled: gp?.lynxPlugins.is3dEnabled ?? false,
  );
  if (l3d != null) {
    boot['lynx3d'] = l3d;
  } else {
    boot.remove('lynx3d');
  }
  return PlayLoadResult(rustSceneJson: rust, playBootstrap: boot, sceneId: sceneId);
}
