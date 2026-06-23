import 'dart:convert';

import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/lynx_cart_web_store.dart';
import 'package:client/features/engine/runtime/lynx_web_runtime.dart';
import 'package:client/features/engine/runtime/scene_autoload_merge.dart';
import 'package:client/features/engine/runtime/scene_to_engine_json.dart';

import 'web_export_loader.dart';

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

Future<PlayLoadResult> loadPlayPayload(
  String? projectPath, {
  bool freshPlay = false,
  String? sceneIdOverride,
}) async {
  if (projectPath == 'web_game_data') {
    return _loadWebExportedGame(sceneIdOverride: sceneIdOverride);
  }
  if (isLynxCartWebPath(projectPath)) {
    return _loadLynxCartWeb(cartIdFromWebPath(projectPath!), sceneIdOverride: sceneIdOverride);
  }
  return _loadDemoFallback();
}

Future<PlayLoadResult> _loadLynxCartWeb(
  String cartId, {
  String? sceneIdOverride,
}) async {
  final store = lynxCartWebSessionCache[cartId];
  if (store == null) {
    return PlayLoadResult(error: 'Cart $cartId не загружен в сессию');
  }
  final pjText = store.readText('project.json');
  if (pjText == null) {
    return const PlayLoadResult(error: 'В cart нет project.json');
  }
  GameProject gp;
  try {
    gp = GameProject.fromJson(jsonDecode(pjText) as Map<String, dynamic>);
  } catch (_) {
    return const PlayLoadResult(error: 'Некорректный project.json в cart');
  }
  final runtime = gp.webRuntime == LynxWebRuntime.webSceneEngine
      ? LynxWebRuntime.lynxCartRuntime
      : gp.webRuntime;
  if (runtime != LynxWebRuntime.lynxCartRuntime) {
    return const PlayLoadResult(
      error: 'Cart требует webRuntime lynx_cart_runtime',
    );
  }
  final sceneId = sceneIdOverride ?? gp.startupSceneId;
  final sceneText = store.readText('scenes/$sceneId.json');
  if (sceneText == null) {
    return PlayLoadResult(error: 'Нет scenes/$sceneId.json в cart', sceneId: sceneId);
  }
  var scene = Scene.fromJson(jsonDecode(sceneText) as Map<String, dynamic>);
  scene = await _mergeAutoloadCart(
    store: store,
    mainScene: scene,
    mainSceneId: sceneId,
    autoloadIds: gp.autoloadSceneIds,
  );

  String? luaCode;
  for (final o in scene.objects) {
    if (o.properties['logicGridGame'] == true && o.scriptId != null) {
      final rel = o.scriptId!.replaceAll('_', '/');
      luaCode = store.readText(rel);
      break;
    }
  }
  luaCode ??= store.readText('assets/scripts/tetris.lua');

  final json = await buildEngineRuntimeSceneJson(
    scene: scene,
    projectRoot: 'cart',
    assets: const [],
    project: gp,
    playSceneId: sceneId,
  );
  final map = jsonDecode(json) as Map<String, dynamic>;
  final rust = jsonEncode({
    'entities': map['entities'],
    'next_id': map['next_id'],
    if (map['tilemaps'] != null) 'tilemaps': map['tilemaps'],
    if (map['rooms'] != null) 'rooms': map['rooms'],
    if (map['cameras'] != null) 'cameras': map['cameras'],
    if (map['camera_center'] != null) 'camera_center': map['camera_center'],
    if (map['input_map'] != null) 'input_map': map['input_map'],
    if (map['scene_id'] != null) 'scene_id': map['scene_id'],
    'logic_grids': <String, dynamic>{},
  });
  final boot = <String, dynamic>{
    'designWidth': gp.designWidth,
    'designHeight': gp.designHeight,
    'pixelPerfect': gp.pixelPerfect,
    if (map['runtime'] is Map) ...(map['runtime'] as Map).cast<String, dynamic>(),
    if (gp.inputMap.isNotEmpty) 'inputMap': gp.inputMap,
    'tilesets': gp.tilesets.map((t) => t.toJson()).toList(),
    'cartRuntime': true,
  };
  return PlayLoadResult(
    rustSceneJson: rust,
    playBootstrap: boot,
    sceneId: sceneId,
    cartLuaScript: luaCode,
    useCartRuntime: true,
  );
}

Future<Scene> _mergeAutoloadCart({
  required LynxCartWebStore store,
  required Scene mainScene,
  required String mainSceneId,
  required List<String> autoloadIds,
}) async {
  if (autoloadIds.isEmpty) return mainScene;
  final merged = List<SceneObject>.from(mainScene.objects);
  for (final aid in autoloadIds) {
    if (aid == mainSceneId) continue;
    final text = store.readText('scenes/$aid.json');
    if (text == null) continue;
    try {
      final auto = Scene.fromJson(jsonDecode(text) as Map<String, dynamic>);
      for (final o in auto.objects) {
        merged.add(
          o.copyWith(
            id: 'autoload_${aid}_${o.id}',
            name: '[${aid}] ${o.name}',
            properties: {...o.properties, 'lynxAutoload': aid},
          ),
        );
      }
    } catch (_) {}
  }
  return Scene(
    id: mainScene.id,
    name: mainScene.name,
    objects: merged,
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

Future<PlayLoadResult> _loadWebExportedGame({String? sceneIdOverride}) async {
  final pjText = await fetchWebGameDataText('project.json');
  if (pjText == null) {
    return const PlayLoadResult(error: 'Нет web/game_data/project.json (сделайте экспорт Web)');
  }
  GameProject? gp;
  try {
    gp = GameProject.fromJson(jsonDecode(pjText) as Map<String, dynamic>);
  } catch (_) {
    return const PlayLoadResult(error: 'Некорректный project.json');
  }
  if (gp.webRuntime == LynxWebRuntime.lynxCartRuntime) {
    return const PlayLoadResult(
      error: 'Для lynx_cart_runtime используйте Arcade / .lynxcart',
    );
  }
  final sceneId = sceneIdOverride ?? gp.startupSceneId;
  final sceneText = await fetchWebGameDataText('scenes/$sceneId.json');
  if (sceneText == null) {
    return PlayLoadResult(error: 'Нет scenes/$sceneId.json', sceneId: sceneId);
  }
  var scene = Scene.fromJson(jsonDecode(sceneText) as Map<String, dynamic>);
  scene = await _mergeAutoloadWeb(
    mainScene: scene,
    mainSceneId: sceneId,
    autoloadIds: gp.autoloadSceneIds,
  );

  final json = await buildEngineRuntimeSceneJson(
    scene: scene,
    projectRoot: 'web_game_data',
    assets: const [],
    project: gp,
    playSceneId: sceneId,
  );
  final map = jsonDecode(json) as Map<String, dynamic>;
  final rust = jsonEncode({
    'entities': map['entities'],
    'next_id': map['next_id'],
    if (map['tilemaps'] != null) 'tilemaps': map['tilemaps'],
    if (map['rooms'] != null) 'rooms': map['rooms'],
    if (map['cameras'] != null) 'cameras': map['cameras'],
    if (map['camera_center'] != null) 'camera_center': map['camera_center'],
    if (map['input_map'] != null) 'input_map': map['input_map'],
    if (map['scene_id'] != null) 'scene_id': map['scene_id'],
  });
  final boot = <String, dynamic>{
    'designWidth': gp.designWidth,
    'designHeight': gp.designHeight,
    if (map['runtime'] is Map) ...(map['runtime'] as Map).cast<String, dynamic>(),
    if (gp.inputMap.isNotEmpty) 'inputMap': gp.inputMap,
    'tilesets': gp.tilesets.map((t) => t.toJson()).toList(),
  };
  return PlayLoadResult(rustSceneJson: rust, playBootstrap: boot, sceneId: sceneId);
}

Future<Scene> _mergeAutoloadWeb({
  required Scene mainScene,
  required String mainSceneId,
  required List<String> autoloadIds,
}) async {
  if (autoloadIds.isEmpty) return mainScene;
  final merged = List<SceneObject>.from(mainScene.objects);
  for (final aid in autoloadIds) {
    if (aid == mainSceneId) continue;
    final text = await fetchWebGameDataText('scenes/$aid.json');
    if (text == null) continue;
    try {
      final auto = Scene.fromJson(jsonDecode(text) as Map<String, dynamic>);
      for (final o in auto.objects) {
        merged.add(
          o.copyWith(
            id: 'autoload_${aid}_${o.id}',
            name: '[${aid}] ${o.name}',
            properties: {...o.properties, 'lynxAutoload': aid},
          ),
        );
      }
    } catch (_) {}
  }
  return Scene(
    id: mainScene.id,
    name: mainScene.name,
    objects: merged,
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

PlayLoadResult _loadDemoFallback() {
  final demo = <String, dynamic>{
    'entities': [
      {
        'id': 0,
        'name': 'Ground',
        'transform': {
          'pos': {'x': 640.0, 'y': 680.0},
          'size': {'x': 1280.0, 'y': 48.0},
          'rot': 0.0,
        },
        'sprite': {'color_hex': 0xFF2E7D32, 'texture_path': null},
        'physics': null,
        'script': null,
        'visible': true,
        'on_ground': false,
      },
    ],
    'next_id': 1,
    'runtime': {
      'designWidth': 1280.0,
      'designHeight': 720.0,
      'camera': {'x': 640.0, 'y': 360.0, 'zoom': 1.0},
    },
  };
  final rust = jsonEncode({
    'entities': demo['entities'],
    'next_id': demo['next_id'],
  });
  final boot = Map<String, dynamic>.from(demo['runtime'] as Map);
  return PlayLoadResult(rustSceneJson: rust, playBootstrap: boot);
}
