import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../game/png_size_reader.dart';
import '../models/engine_models.dart';
import '../../plugins/lynx_plugin_host.dart';
import 'collider_from_sprite_meta.dart';
import 'engine_color_codec.dart';
import 'input_map_codec.dart';
import 'tic_grid_codec.dart';
import '../../plugins/lynx_plugin_manifest.dart';

const String kDefaultPlayerLua = r'''-- Платформер: WASD / Space — прыжок; nexus_log("msg") — лог в панели F1; play_sound("assets/sounds/hit.wav") — звук из проекта
local speed = 260
local jump = 520
local nvx = 0
local nvy = vy

if key_a then nvx = -speed end
if key_d then nvx = speed end
if not key_a and not key_d then nvx = 0 end

if key_space and on_ground then
  nvy = -jump
end

set_velocity(nvx, nvy)
''';

int _sortingLayerSortOrder(Scene scene, String? layerId) {
  final id = layerId ?? SceneLayer.defaultLayerId;
  for (final l in scene.layers) {
    if (l.id == id) return l.sortOrder;
  }
  return 0;
}

int _sortingLayerForExport(Scene scene, SceneObject o) {
  final ovr = o.properties['sortingLayerOverride'];
  if (ovr is int) return ovr;
  if (ovr is num) return ovr.toInt();
  return _sortingLayerSortOrder(scene, o.layerId);
}

int _orderInLayerFromZ(double z) => (z * 1000).round().clamp(-8000000, 8000000);

bool _isStaticObject(SceneObject o) {
  final n = o.name.toLowerCase();
  if (n.contains('ground') || n.contains('floor') || n.contains('platform')) {
    return true;
  }
  final p = o.properties['static'];
  return p == true || p == 'true';
}

Future<SpriteAssetMeta?> _spriteMetaForObject({
  required SceneObject o,
  required String projectRoot,
  required List<ProjectAsset> assets,
}) async {
  ProjectAsset? hit;
  for (final a in assets) {
    if (a.id == o.assetId) {
      hit = a;
      break;
    }
  }
  if (hit?.spriteMeta != null) return hit!.spriteMeta;
  if (hit != null && hit.type == 'sprite') {
    final baseDir = p.dirname(hit.path);
    final baseName = p.basenameWithoutExtension(hit.path);
    final metaPath = p.join(projectRoot, baseDir, '$baseName.meta.json');
    final f = File(metaPath);
    if (await f.exists()) {
      try {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        return SpriteAssetMeta.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {}
    }
  }
  return null;
}

Future<(double?, double?)> _texturePixelSize(String projectRoot, String relPath) async {
  final abs = p.join(projectRoot, relPath);
  final f = File(abs);
  if (!await f.exists()) return (null, null);
  final ext = p.extension(relPath).toLowerCase();
  if (ext != '.png') return (null, null);
  final raf = await f.open();
  try {
    final head = await raf.read(32);
    final sz = readPngIntrinsicSize(Uint8List.fromList(head));
    if (sz == null) return (null, null);
    return (sz.$1?.toDouble(), sz.$2?.toDouble());
  } finally {
    await raf.close();
  }
}

Future<String> buildEngineRuntimeSceneJson({
  required Scene scene,
  required String projectRoot,
  required List<ProjectAsset> assets,
  required GameProject? project,
  String? playSceneId,
}) async {
  final designW = project?.designWidth ?? 1280;
  final designH = project?.designHeight ?? 720;

  final entities = <Map<String, dynamic>>[];
  final rustIdBySceneObjectId = <String, int>{};
  var _allocRustId = 0;
  for (final o in scene.objects) {
    if (!o.active) continue;
    final hasScript = o.scriptId != null && o.scriptId!.isNotEmpty;
    if (!o.visible && !hasScript) continue;
    rustIdBySceneObjectId[o.id] = _allocRustId++;
  }
  var nextId = _allocRustId;
  int? cameraTargetRustId;
  final followId = scene.camera.followInstanceId;
  if (followId != null) {
    cameraTargetRustId = rustIdBySceneObjectId[followId];
  }

  Future<String?> loadScriptSource(String? scriptAssetId) async {
    if (scriptAssetId == null || scriptAssetId.isEmpty) return null;
    ProjectAsset? scriptAsset;
    for (final a in assets) {
      if (a.id == scriptAssetId) {
        scriptAsset = a;
        break;
      }
    }
    if (scriptAsset == null) {
      for (final a in assets) {
        if (a.type == 'script' &&
            (scriptAssetId.contains(a.id) || a.path.endsWith(scriptAssetId))) {
          scriptAsset = a;
          break;
        }
      }
    }
    if (scriptAsset == null || scriptAsset.type != 'script') return null;
    final f = File(p.join(projectRoot, scriptAsset.path));
    if (!await f.exists()) return null;
    return f.readAsString();
  }

  for (final o in scene.objects) {
    if (!o.active) continue;
    final hasScript = o.scriptId != null && o.scriptId!.isNotEmpty;
    if (!o.visible && !hasScript) continue;
    final rustId = rustIdBySceneObjectId[o.id]!;

    final spriteMeta = await _spriteMetaForObject(
      o: o,
      projectRoot: projectRoot,
      assets: assets,
    );
    final colliderBox = computeColliderWorldAabb(o, spriteMeta);
    final staticBody = _isStaticObject(o);

    Color tint = Colors.blueGrey.shade400;
    final tc = o.properties['tint'];
    if (tc is int) {
      tint = Color(tc);
    }

    String? code;
    if (o.scriptId != null) {
      code = await loadScriptSource(o.scriptId);
    }
    if (code == null) {
      final inline = o.properties['script'];
      if (inline is Map && inline['code'] is String) {
        code = inline['code'] as String;
      }
    }
    if (code == null && !staticBody && o.assetId == 'test') {
      code = kDefaultPlayerLua;
    }

    final shapeStr = (o.properties['physicsShape'] as String? ?? 'aabb').toLowerCase();
    final shape = shapeStr == 'circle' ? 'circle' : 'aabb';

    final physics = staticBody
        ? null
        : {
            'velocity': {'x': 0.0, 'y': 0.0},
            'mass': (o.properties['mass'] as num?)?.toDouble() ?? 1.0,
            'is_static': false,
            'use_gravity': o.properties['useGravity'] != false,
            'bounciness': (o.properties['bounciness'] as num?)?.toDouble() ?? 0.05,
            'shape': shape,
            'collision_layer': (o.properties['collisionLayer'] as num?)?.toInt() ?? 1,
            'collision_mask': (o.properties['collisionMask'] as num?)?.toInt() ?? 0xFFFF,
            'is_trigger': o.properties['isTrigger'] == true,
            'one_way': o.properties['physicsOneWay'] == true,
          };

    final vw = o.width * o.scaleX;
    final vh = o.height * o.scaleY;
    final vox = o.x - colliderBox.centerX;
    final voy = o.y - colliderBox.centerY;

    String? texRel;
    double? texW;
    double? texH;
    Map<String, dynamic>? uvRect;
    Map<String, dynamic>? animJson;
    ProjectAsset? spriteHit;
    for (final a in assets) {
      if (a.id == o.assetId) {
        spriteHit = a;
        break;
      }
    }
    if (spriteHit != null && spriteHit.type == 'sprite' && o.assetId != 'test') {
      texRel = spriteHit.path.replaceAll('\\', '/');
      final dims = await _texturePixelSize(projectRoot, spriteHit.path);
      texW = dims.$1;
      texH = dims.$2;
      final anim = spriteMeta?.sheetAnimation;
      if (anim != null && anim.frames.isNotEmpty) {
        animJson = {
          'frames': [
            for (final fr in anim.frames)
              {'x': fr.x, 'y': fr.y, 'w': fr.w, 'h': fr.h},
          ],
          'fps': anim.fps,
        };
        final f0 = anim.frames.first;
        uvRect = {'x': f0.x, 'y': f0.y, 'w': f0.w, 'h': f0.h};
      } else if (texW != null && texH != null) {
        uvRect = {'x': 0.0, 'y': 0.0, 'w': texW, 'h': texH};
      }
    }

    final ent = <String, dynamic>{
      'id': rustId,
      'name': o.name,
      'transform': {
        'pos': {'x': colliderBox.centerX, 'y': colliderBox.centerY},
        'size': {'x': colliderBox.width, 'y': colliderBox.height},
        'rot': o.rotation,
      },
      'sprite': {
        'color_hex': flutterColorToEngineArgb(tint),
        'texture_path': texRel,
        if (texW != null) 'texture_width': texW,
        if (texH != null) 'texture_height': texH,
        if (uvRect != null) 'uv_rect': uvRect,
        if (animJson != null) 'animation': animJson,
        'visual_offset': {'x': vox, 'y': voy},
        'visual_width': vw,
        'visual_height': vh,
        'sorting_layer': _sortingLayerForExport(scene, o),
        'order_in_layer': _orderInLayerFromZ(o.z),
      },
      'physics': physics,
      'script': code != null ? {'code': code} : null,
      'visible': o.visible,
      'on_ground': false,
    };
    if (animJson != null) {
      ent['animator'] = const {
        'clip_id': 'default',
        'time': 0.0,
        'speed': 1.0,
        'looping': true,
      };
    }
    final rpm = o.properties['rustPlatformerMotor'];
    if (rpm is Map) ent['platformer_motor'] = Map<String, dynamic>.from(rpm);
    final rpa = o.properties['rustPatrolAi'];
    if (rpa is Map) ent['patrol_ai'] = Map<String, dynamic>.from(rpa);
    final rbt = o.properties['rustBehaviorTree'];
    if (rbt is Map) {
      final m = Map<String, dynamic>.from(rbt);
      if (m.containsKey('root')) {
        ent['behavior_tree'] = m;
      } else {
        ent['behavior_tree'] = {'root': m};
      }
    }
    final rasm = o.properties['rustAnimStateMachine'];
    if (rasm is Map) ent['anim_state_machine'] = Map<String, dynamic>.from(rasm);
    final rac = o.properties['rustAnimationClips'];
    if (rac is Map) {
      ent['animation_clips'] = rac.map((k, v) => MapEntry(k.toString(), v));
    }
    final pSceneId = o.parentId;
    if (pSceneId != null) {
      final pr = rustIdBySceneObjectId[pSceneId];
      if (pr != null) {
        ent['parent_id'] = pr;
      }
    }
    entities.add(ent);
  }

  final hasFloor = entities.any((e) {
    final name = (e['name'] as String? ?? '').toLowerCase();
    final phy = e['physics'];
    if (phy != null) return false;
    final pos = (e['transform'] as Map)['pos'] as Map;
    final y = (pos['y'] as num).toDouble();
    return name.contains('ground') || name.contains('floor') || y > designH * 0.55;
  });

  final skipAutoGround = project?.gameTemplate == 'tetris' ||
      project?.gameTemplate == 'tic' ||
      project?.projectMode == LynxProjectMode.tic ||
      scene.objects.any((o) => (o.scriptId ?? '').contains('tetris'));

  if (!hasFloor && !skipAutoGround) {
    entities.add({
      'id': nextId,
      'name': 'Ground',
      'transform': {
        'pos': {'x': designW / 2, 'y': designH - 24},
        'size': {'x': designW + 200, 'y': 48},
        'rot': 0.0,
      },
      'sprite': {
        'color_hex': flutterColorToEngineArgb(Colors.green.shade800),
        'texture_path': null,
        'visual_offset': {'x': 0.0, 'y': 0.0},
        'visual_width': designW + 200,
        'visual_height': 48,
      },
      'physics': null,
      'script': null,
      'visible': true,
      'on_ground': false,
    });
    nextId++;
  }

  final engineInputMap = normalizeInputMapForEngine(project?.inputMap);
  var camX = scene.camera.x;
  var camY = scene.camera.y;
  if (camX == 0 && camY == 0 && scene.camera.followInstanceId == null) {
    camX = designW / 2;
    camY = designH / 2;
  }
  final map = {
    'entities': entities,
    'next_id': nextId,
    'scene_id': playSceneId ?? scene.id,
    if (engineInputMap.isNotEmpty) 'input_map': engineInputMap,
    'camera_center': {'x': camX, 'y': camY},
    'cameras': [
      {
        'name': 'Main',
        'active': true,
        'target_entity_id': cameraTargetRustId,
        'offset': {'x': 0.0, 'y': 0.0},
        'smoothing': 8.0,
        'zoom': scene.camera.zoom,
        'dead_zone_half_w': scene.camera.deadZoneHalfW,
        'dead_zone_half_h': scene.camera.deadZoneHalfH,
      },
    ],
    'audio_mixer': {
      'master_volume': (project?.audioMasterVolume ?? 1.0).clamp(0.0, 4.0),
      'bus_volumes': <String, dynamic>{
        for (final e in (project?.audioBusVolumes ?? {}).entries) e.key: e.value,
      },
    },
    'tilemaps': scene.tilemaps.map((l) => l.toRustJson()).toList(),
    'rooms': scene.rooms.map((r) => r.toRustJson()).toList(),
    'runtime': {
      'designWidth': designW,
      'designHeight': designH,
      'camera': {
        'x': camX,
        'y': camY,
        'zoom': scene.camera.zoom,
      },
      if (project?.inputMap.isNotEmpty ?? false) 'inputMap': project!.inputMap,
    },
  };

  final pluginMerge = LynxPluginHost.instance.mergeSceneExport(scene.toJson());
  if (pluginMerge.extensions.isNotEmpty) {
    map['extensions'] = pluginMerge.extensions;
  }
  if (pluginMerge.enabledPluginIds.isNotEmpty) {
    map['enabled_plugins'] = pluginMerge.enabledPluginIds;
  }

  if (projectUsesTicApi(
    gameTemplate: project?.gameTemplate,
    projectMode: project?.projectMode.jsonValue,
  )) {
    map['logic_grids'] = await loadTicLogicGridsForExport(projectRoot);
  }

  return jsonEncode(map);
}
