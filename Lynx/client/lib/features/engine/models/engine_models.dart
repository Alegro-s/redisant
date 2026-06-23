import 'dart:math' as math;

import '../../plugins/lynx_plugin_manifest.dart';
import '../runtime/lynx_web_runtime.dart';
import '../runtime/lynx_windows_3d_runtime.dart';

const int kSceneFormatVersion = 3;

class LynxCloudPublish {
  const LynxCloudPublish({
    this.enabled = false,
    this.tier = 'free_to_play',
    this.title = '',
    this.tags = const [],
  });

  final bool enabled;
  final String tier;
  final String title;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'tier': tier,
        'title': title,
        'tags': tags,
      };

  factory LynxCloudPublish.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LynxCloudPublish();
    return LynxCloudPublish(
      enabled: json['enabled'] as bool? ?? false,
      tier: json['tier'] as String? ?? 'free_to_play',
      title: json['title'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
    );
  }
}

class GameProject {
  final String projectId;
  final int settingsVersion;
  final String displayName;
  final String gameTemplate;
  final String startupSceneId;
  /// Autoload-сцены (синглтоны), подмешиваются при каждом Play.
  final List<String> autoloadSceneIds;
  final double designWidth;
  final double designHeight;
  final bool pixelPerfect;
  final double defaultGravityY;
  final double pixelsPerUnit;
  final List<String> physicsLayers;
  final Map<String, dynamic> inputMap;
  final List<ProjectTileset> tilesets;
  final double audioMasterVolume;
  final Map<String, double> audioBusVolumes;
  final String? minNexusEngineVersion;
  /// Минимальная semver Lynx Core внутри `engine.dll` (волна 11d).
  final String? minLynxCoreVersion;
  final String? studioEngineBoundVersion;
  final LynxWebRuntime webRuntime;
  /// Windows Player: Canvas 3D или D3D12 Core viewport (Q3).
  final LynxWindows3dRuntime windows3dRuntime;
  final LynxProjectMode projectMode;
  final LynxProjectPlugins lynxPlugins;
  final LynxCloudPublish? cloudPublish;

  GameProject({
    required this.projectId,
    this.settingsVersion = 1,
    required this.displayName,
    this.gameTemplate = 'empty',
    this.startupSceneId = 'main',
    List<String>? autoloadSceneIds,
    this.designWidth = 1280,
    this.designHeight = 720,
    this.pixelPerfect = false,
    this.defaultGravityY = 980,
    this.pixelsPerUnit = 1,
    List<String>? physicsLayers,
    Map<String, dynamic>? inputMap,
    List<ProjectTileset>? tilesets,
    this.audioMasterVolume = 1.0,
    Map<String, double>? audioBusVolumes,
    this.minNexusEngineVersion,
    this.minLynxCoreVersion,
    this.studioEngineBoundVersion,
    this.webRuntime = LynxWebRuntime.webSceneEngine,
    this.windows3dRuntime = LynxWindows3dRuntime.canvasPreview,
    this.projectMode = LynxProjectMode.d2,
    LynxProjectPlugins? lynxPlugins,
    this.cloudPublish,
  })  : autoloadSceneIds = autoloadSceneIds ?? const [],
        physicsLayers = physicsLayers ?? const ['default', 'ui'],
        inputMap = inputMap ?? const {},
        tilesets = tilesets ?? const [],
        audioBusVolumes = audioBusVolumes ?? <String, double>{},
        lynxPlugins = lynxPlugins ?? const LynxProjectPlugins();

  Map<String, dynamic> toJson() => {
        'settingsVersion': settingsVersion,
        'projectId': projectId,
        'displayName': displayName,
        'gameTemplate': gameTemplate,
        'startupSceneId': startupSceneId,
        if (autoloadSceneIds.isNotEmpty) 'autoloadSceneIds': autoloadSceneIds,
        'designWidth': designWidth,
        'designHeight': designHeight,
        'pixelPerfect': pixelPerfect,
        'defaultGravityY': defaultGravityY,
        'pixelsPerUnit': pixelsPerUnit,
        'physicsLayers': physicsLayers,
        'inputMap': inputMap,
        'tilesets': tilesets.map((t) => t.toJson()).toList(),
        'audioMasterVolume': audioMasterVolume,
        'audioBusVolumes': audioBusVolumes,
        if (minNexusEngineVersion != null) 'minNexusEngineVersion': minNexusEngineVersion,
        if (minLynxCoreVersion != null) 'minLynxCoreVersion': minLynxCoreVersion,
        if (studioEngineBoundVersion != null) 'studioEngineBoundVersion': studioEngineBoundVersion,
        if (webRuntime != LynxWebRuntime.webSceneEngine) 'webRuntime': webRuntime.jsonValue,
        if (windows3dRuntime != LynxWindows3dRuntime.canvasPreview)
          'windows3dRuntime': windows3dRuntime.jsonValue,
        'projectMode': projectMode.jsonValue,
        'lynxPlugins': lynxPlugins.toJson(),
        if (cloudPublish != null) 'cloudPublish': cloudPublish!.toJson(),
      };

  factory GameProject.fromJson(Map<String, dynamic> json) {
    return GameProject(
      projectId: json['projectId'] as String? ?? '',
      settingsVersion: (json['settingsVersion'] as num?)?.toInt() ?? 1,
      displayName: json['displayName'] as String? ?? 'Untitled',
      gameTemplate: json['gameTemplate'] as String? ?? 'empty',
      startupSceneId: json['startupSceneId'] as String? ?? 'main',
      autoloadSceneIds: (json['autoloadSceneIds'] as List?)?.cast<String>() ?? const [],
      designWidth: (json['designWidth'] as num?)?.toDouble() ?? 1280,
      designHeight: (json['designHeight'] as num?)?.toDouble() ?? 720,
      pixelPerfect: json['pixelPerfect'] as bool? ?? false,
      defaultGravityY: (json['defaultGravityY'] as num?)?.toDouble() ?? 980,
      pixelsPerUnit: (json['pixelsPerUnit'] as num?)?.toDouble() ?? 1,
      physicsLayers: (json['physicsLayers'] as List?)?.cast<String>(),
      inputMap: (json['inputMap'] as Map?)?.cast<String, dynamic>(),
      tilesets: (json['tilesets'] as List?)
              ?.map((e) => ProjectTileset.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      audioMasterVolume: (json['audioMasterVolume'] as num?)?.toDouble() ?? 1.0,
      audioBusVolumes: (json['audioBusVolumes'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ) ??
          <String, double>{},
      minNexusEngineVersion: json['minNexusEngineVersion'] as String?,
      minLynxCoreVersion: json['minLynxCoreVersion'] as String?,
      studioEngineBoundVersion: json['studioEngineBoundVersion'] as String?,
      webRuntime: LynxWebRuntimeJson.fromJson(json['webRuntime'] as String?),
      windows3dRuntime:
          LynxWindows3dRuntimeJson.fromJson(json['windows3dRuntime'] as String?),
      projectMode: LynxProjectMode.fromJson(json['projectMode'] as String?),
      lynxPlugins: LynxProjectPlugins.fromJson(
        json['lynxPlugins'] as Map<String, dynamic>?,
      ),
      cloudPublish: LynxCloudPublish.fromJson(
        json['cloudPublish'] as Map<String, dynamic>?,
      ),
    );
  }

  GameProject copyWith({
    String? displayName,
    String? gameTemplate,
    String? startupSceneId,
    List<String>? autoloadSceneIds,
    double? designWidth,
    double? designHeight,
    bool? pixelPerfect,
    double? defaultGravityY,
    double? pixelsPerUnit,
    List<String>? physicsLayers,
    Map<String, dynamic>? inputMap,
    List<ProjectTileset>? tilesets,
    double? audioMasterVolume,
    Map<String, double>? audioBusVolumes,
    String? minNexusEngineVersion,
    String? minLynxCoreVersion,
    String? studioEngineBoundVersion,
    LynxWebRuntime? webRuntime,
    LynxWindows3dRuntime? windows3dRuntime,
    LynxProjectMode? projectMode,
    LynxProjectPlugins? lynxPlugins,
    LynxCloudPublish? cloudPublish,
  }) {
    return GameProject(
      projectId: projectId,
      settingsVersion: settingsVersion,
      displayName: displayName ?? this.displayName,
      gameTemplate: gameTemplate ?? this.gameTemplate,
      startupSceneId: startupSceneId ?? this.startupSceneId,
      autoloadSceneIds: autoloadSceneIds ?? this.autoloadSceneIds,
      designWidth: designWidth ?? this.designWidth,
      designHeight: designHeight ?? this.designHeight,
      pixelPerfect: pixelPerfect ?? this.pixelPerfect,
      defaultGravityY: defaultGravityY ?? this.defaultGravityY,
      pixelsPerUnit: pixelsPerUnit ?? this.pixelsPerUnit,
      physicsLayers: physicsLayers ?? this.physicsLayers,
      inputMap: inputMap ?? this.inputMap,
      tilesets: tilesets ?? this.tilesets,
      audioMasterVolume: audioMasterVolume ?? this.audioMasterVolume,
      audioBusVolumes: audioBusVolumes ?? this.audioBusVolumes,
      minNexusEngineVersion: minNexusEngineVersion ?? this.minNexusEngineVersion,
      minLynxCoreVersion: minLynxCoreVersion ?? this.minLynxCoreVersion,
      studioEngineBoundVersion: studioEngineBoundVersion ?? this.studioEngineBoundVersion,
      webRuntime: webRuntime ?? this.webRuntime,
      windows3dRuntime: windows3dRuntime ?? this.windows3dRuntime,
      projectMode: projectMode ?? this.projectMode,
      lynxPlugins: lynxPlugins ?? this.lynxPlugins,
      cloudPublish: cloudPublish ?? this.cloudPublish,
    );
  }

  static GameProject fresh({required String displayName}) {
    return GameProject(
      projectId: generateProjectUuid(),
      displayName: displayName,
    );
  }
}

String generateProjectUuid() {
  final r = math.Random();
  final hex = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

class ProjectTileset {
  final String id;
  final String texturePath;
  final int columns;
  final double tileWidth;
  final double tileHeight;

  const ProjectTileset({
    required this.id,
    required this.texturePath,
    this.columns = 16,
    this.tileWidth = 32,
    this.tileHeight = 32,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'texturePath': texturePath,
        'columns': columns,
        'tileWidth': tileWidth,
        'tileHeight': tileHeight,
      };

  factory ProjectTileset.fromJson(Map<String, dynamic> json) {
    final tw = (json['tileWidth'] as num?)?.toDouble() ?? 32;
    return ProjectTileset(
      id: json['id'] as String? ?? 'default',
      texturePath: (json['texturePath'] as String? ?? '').replaceAll('\\', '/'),
      columns: (json['columns'] as num?)?.toInt() ?? 16,
      tileWidth: tw,
      tileHeight: (json['tileHeight'] as num?)?.toDouble() ?? tw,
    );
  }

  ProjectTileset copyWith({
    String? id,
    String? texturePath,
    int? columns,
    double? tileWidth,
    double? tileHeight,
  }) {
    return ProjectTileset(
      id: id ?? this.id,
      texturePath: texturePath ?? this.texturePath,
      columns: columns ?? this.columns,
      tileWidth: tileWidth ?? this.tileWidth,
      tileHeight: tileHeight ?? this.tileHeight,
    );
  }
}


enum SpriteColliderKind {
  none,
  aabb,
  circle;

  static SpriteColliderKind fromString(String? s) {
    switch (s) {
      case 'aabb':
        return SpriteColliderKind.aabb;
      case 'circle':
        return SpriteColliderKind.circle;
      default:
        return SpriteColliderKind.none;
    }
  }

  String toJsonValue() => name;
}

class SpriteAnimFrameMeta {
  final double x;
  final double y;
  final double w;
  final double h;

  const SpriteAnimFrameMeta({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory SpriteAnimFrameMeta.fromJson(Map<String, dynamic> json) {
    return SpriteAnimFrameMeta(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      w: (json['w'] as num?)?.toDouble() ?? 0,
      h: (json['h'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SpriteSheetAnimMeta {
  final List<SpriteAnimFrameMeta> frames;
  final double fps;

  const SpriteSheetAnimMeta({
    required this.frames,
    this.fps = 8,
  });

  Map<String, dynamic> toJson() => {
        'frames': frames.map((f) => f.toJson()).toList(),
        'fps': fps,
      };

  factory SpriteSheetAnimMeta.fromJson(Map<String, dynamic> json) {
    final raw = json['frames'] as List? ?? [];
    return SpriteSheetAnimMeta(
      fps: (json['fps'] as num?)?.toDouble() ?? 8,
      frames: raw
          .map((e) => SpriteAnimFrameMeta.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class SpriteAssetMeta {
  final double originX;
  final double originY;
  final SpriteColliderKind colliderKind;
  final double colliderOffsetX;
  final double colliderOffsetY;
  final double colliderWidth;
  final double colliderHeight;
  final double colliderRadius;
  final SpriteSheetAnimMeta? sheetAnimation;

  const SpriteAssetMeta({
    this.originX = 0.5,
    this.originY = 0.5,
    this.colliderKind = SpriteColliderKind.none,
    this.colliderOffsetX = 0,
    this.colliderOffsetY = 0,
    this.colliderWidth = 0,
    this.colliderHeight = 0,
    this.colliderRadius = 0,
    this.sheetAnimation,
  });

  Map<String, dynamic> toJson() => {
        'metaVersion': 1,
        'originX': originX,
        'originY': originY,
        'colliderKind': colliderKind.toJsonValue(),
        'colliderOffsetX': colliderOffsetX,
        'colliderOffsetY': colliderOffsetY,
        'colliderWidth': colliderWidth,
        'colliderHeight': colliderHeight,
        'colliderRadius': colliderRadius,
        if (sheetAnimation != null) 'sheetAnimation': sheetAnimation!.toJson(),
      };

  factory SpriteAssetMeta.fromJson(Map<String, dynamic> json) {
    SpriteSheetAnimMeta? anim;
    final a = json['sheetAnimation'] ?? json['animation'];
    if (a is Map) {
      anim = SpriteSheetAnimMeta.fromJson(Map<String, dynamic>.from(a));
    }
    return SpriteAssetMeta(
      originX: (json['originX'] as num?)?.toDouble() ?? 0.5,
      originY: (json['originY'] as num?)?.toDouble() ?? 0.5,
      colliderKind: SpriteColliderKind.fromString(json['colliderKind'] as String?),
      colliderOffsetX: (json['colliderOffsetX'] as num?)?.toDouble() ?? 0,
      colliderOffsetY: (json['colliderOffsetY'] as num?)?.toDouble() ?? 0,
      colliderWidth: (json['colliderWidth'] as num?)?.toDouble() ?? 0,
      colliderHeight: (json['colliderHeight'] as num?)?.toDouble() ?? 0,
      colliderRadius: (json['colliderRadius'] as num?)?.toDouble() ?? 0,
      sheetAnimation: anim,
    );
  }
}


class PrefabDefinition {
  final String id;
  final String name;
  final SceneObject templateRoot;
  final List<SceneObject> children;

  PrefabDefinition({
    required this.id,
    required this.name,
    required this.templateRoot,
    this.children = const [],
  });

  int get prefabVersion => children.isEmpty ? 1 : 2;

  Map<String, dynamic> toJson() => {
        'prefabVersion': prefabVersion,
        'id': id,
        'name': name,
        'templateRoot': templateRoot.toJson(),
        if (children.isNotEmpty) 'children': children.map((e) => e.toJson()).toList(),
      };

  factory PrefabDefinition.fromJson(Map<String, dynamic> json) {
    final rawKids = json['children'] as List?;
    return PrefabDefinition(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Prefab',
      templateRoot: SceneObject.fromJson(Map<String, dynamic>.from(json['templateRoot'] as Map)),
      children: rawKids == null
          ? const []
          : rawKids
              .map((e) => SceneObject.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }
}

List<SceneObject> collectSceneSubtreeOrdered(Scene scene, SceneObject root) {
  final allowed = <String>{root.id};
  var changed = true;
  while (changed) {
    changed = false;
    for (final o in scene.objects) {
      if (allowed.contains(o.id)) continue;
      final p = o.parentId;
      if (p != null && allowed.contains(p)) {
        allowed.add(o.id);
        changed = true;
      }
    }
  }
  final inTree = scene.objects.where((o) => allowed.contains(o.id)).toList();
  if (inTree.length <= 1) return [root];

  final ordered = <SceneObject>[root];
  final pending = inTree.where((o) => o.id != root.id).toList();
  while (pending.isNotEmpty) {
    final i = pending.indexWhere((c) {
      final pid = c.parentId;
      if (pid == null) return true;
      return ordered.any((x) => x.id == pid);
    });
    if (i < 0) {
      ordered.addAll(pending);
      break;
    }
    ordered.add(pending.removeAt(i));
  }
  return ordered;
}

PrefabDefinition buildPrefabDefinitionFromSceneSubtree({
  required String id,
  required String name,
  required List<SceneObject> ordered,
}) {
  if (ordered.isEmpty) {
    throw ArgumentError('ordered');
  }
  final rootOld = ordered.first.id;
  final idMap = <String, String>{rootOld: 'p_root'};
  for (var i = 1; i < ordered.length; i++) {
    idMap[ordered[i].id] = 'p_$i';
  }

  SceneObject toPrefabObject(SceneObject o) {
    final isRoot = o.id == rootOld;
    final newId = idMap[o.id]!;
    String? newParent;
    if (isRoot) {
      newParent = null;
    } else {
      final pid = o.parentId;
      if (pid == null) {
        newParent = 'p_root';
      } else if (idMap.containsKey(pid)) {
        newParent = idMap[pid];
      } else if (pid == rootOld) {
        newParent = 'p_root';
      } else {
        newParent = 'p_root';
      }
    }
    return o.copyWith(
      id: newId,
      parentId: newParent,
      clearParentId: isRoot,
      prefabId: null,
    );
  }

  final templateRoot = toPrefabObject(ordered.first);
  final children = ordered.skip(1).map(toPrefabObject).toList();
  return PrefabDefinition(id: id, name: name, templateRoot: templateRoot, children: children);
}


class SceneLayer {
  static const String defaultLayerId = 'layer_default';
  static const String uiLayerId = 'layer_ui';

  final String id;
  final String name;
  final int sortOrder;
  final bool visible;
  final double parallaxX;
  final double parallaxY;

  const SceneLayer({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.visible = true,
    this.parallaxX = 1,
    this.parallaxY = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sortOrder': sortOrder,
        'visible': visible,
        'parallaxX': parallaxX,
        'parallaxY': parallaxY,
      };

  factory SceneLayer.fromJson(Map<String, dynamic> json) {
    return SceneLayer(
      id: json['id'] as String? ?? defaultLayerId,
      name: json['name'] as String? ?? 'Layer',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      visible: json['visible'] as bool? ?? true,
      parallaxX: (json['parallaxX'] as num?)?.toDouble() ?? 1,
      parallaxY: (json['parallaxY'] as num?)?.toDouble() ?? 1,
    );
  }

  SceneLayer copyWith({
    String? id,
    String? name,
    int? sortOrder,
    bool? visible,
    double? parallaxX,
    double? parallaxY,
  }) {
    return SceneLayer(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      visible: visible ?? this.visible,
      parallaxX: parallaxX ?? this.parallaxX,
      parallaxY: parallaxY ?? this.parallaxY,
    );
  }
}

class SceneCamera {
  final double x;
  final double y;
  final double zoom;
  final String? followInstanceId;
  final double deadZoneHalfW;
  final double deadZoneHalfH;

  const SceneCamera({
    this.x = 0,
    this.y = 0,
    this.zoom = 1,
    this.followInstanceId,
    this.deadZoneHalfW = 0,
    this.deadZoneHalfH = 0,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'zoom': zoom,
        'followInstanceId': followInstanceId,
        'deadZoneHalfW': deadZoneHalfW,
        'deadZoneHalfH': deadZoneHalfH,
      };

  factory SceneCamera.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SceneCamera();
    return SceneCamera(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      zoom: (json['zoom'] as num?)?.toDouble() ?? 1,
      followInstanceId: json['followInstanceId'] as String?,
      deadZoneHalfW: (json['deadZoneHalfW'] as num?)?.toDouble() ?? 0,
      deadZoneHalfH: (json['deadZoneHalfH'] as num?)?.toDouble() ?? 0,
    );
  }
}


class TileChunkData {
  final int cx;
  final int cy;
  final int tw;
  final int th;
  final List<int> tileIds;
  final List<int> collision;

  const TileChunkData({
    required this.cx,
    required this.cy,
    required this.tw,
    required this.th,
    this.tileIds = const [],
    this.collision = const [],
  });

  Map<String, dynamic> toRustJson() => {
        'cx': cx,
        'cy': cy,
        'tw': tw,
        'th': th,
        'tile_ids': tileIds,
        'collision': collision,
      };

  factory TileChunkData.fromJson(Map<String, dynamic> json) {
    return TileChunkData(
      cx: (json['cx'] as num?)?.toInt() ?? 0,
      cy: (json['cy'] as num?)?.toInt() ?? 0,
      tw: (json['tw'] as num?)?.toInt() ?? 32,
      th: (json['th'] as num?)?.toInt() ?? 32,
      tileIds: (json['tile_ids'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      collision: (json['collision'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [],
    );
  }
}

class TilemapLayerData {
  final String id;
  final double tileW;
  final double tileH;
  final int zOrder;
  final bool visible;
  final String? tilesetId;
  final bool autotile;
  final List<TileChunkData> chunks;

  const TilemapLayerData({
    required this.id,
    this.tileW = 32,
    this.tileH = 32,
    this.zOrder = 0,
    this.visible = true,
    this.tilesetId,
    this.autotile = false,
    this.chunks = const [],
  });

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'tile_w': tileW,
        'tile_h': tileH,
        'z_order': zOrder,
        'visible': visible,
        if (tilesetId != null && tilesetId!.isNotEmpty) 'tileset_id': tilesetId,
        'autotile': autotile,
        'chunks': chunks.map((c) => c.toRustJson()).toList(),
      };

  factory TilemapLayerData.fromJson(Map<String, dynamic> json) {
    final raw = json['chunks'] as List? ?? [];
    final ts = json['tileset_id'] as String? ?? json['tilesetId'] as String?;
    return TilemapLayerData(
      id: json['id'] as String? ?? 'main',
      tileW: (json['tile_w'] as num?)?.toDouble() ?? (json['tileW'] as num?)?.toDouble() ?? 32,
      tileH: (json['tile_h'] as num?)?.toDouble() ?? (json['tileH'] as num?)?.toDouble() ?? 32,
      zOrder: (json['z_order'] as num?)?.toInt() ?? (json['zOrder'] as num?)?.toInt() ?? 0,
      visible: json['visible'] as bool? ?? true,
      tilesetId: ts,
      autotile: json['autotile'] as bool? ?? false,
      chunks: raw.map((e) => TileChunkData.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }

  TilemapLayerData copyWith({
    String? id,
    double? tileW,
    double? tileH,
    int? zOrder,
    bool? visible,
    String? tilesetId,
    bool? autotile,
    List<TileChunkData>? chunks,
    bool clearTilesetId = false,
  }) {
    return TilemapLayerData(
      id: id ?? this.id,
      tileW: tileW ?? this.tileW,
      tileH: tileH ?? this.tileH,
      zOrder: zOrder ?? this.zOrder,
      visible: visible ?? this.visible,
      tilesetId: clearTilesetId ? null : (tilesetId ?? this.tilesetId),
      autotile: autotile ?? this.autotile,
      chunks: chunks ?? this.chunks,
    );
  }
}

class RoomZoneData {
  final String id;
  final double x;
  final double y;
  final double w;
  final double h;
  final double cameraMinX;
  final double cameraMinY;
  final double cameraMaxX;
  final double cameraMaxY;
  /// ID сцены (`scenes/*.json`), связанной с этой комнатой — отдельный холст.
  final String? targetSceneId;

  const RoomZoneData({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.cameraMinX = 0,
    this.cameraMinY = 0,
    this.cameraMaxX = 0,
    this.cameraMaxY = 0,
    this.targetSceneId,
  });

  Map<String, dynamic> toRustJson() => {
        'id': id,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'camera_min_x': cameraMinX,
        'camera_min_y': cameraMinY,
        'camera_max_x': cameraMaxX,
        'camera_max_y': cameraMaxY,
        if (targetSceneId != null && targetSceneId!.isNotEmpty)
          'target_scene_id': targetSceneId,
      };

  factory RoomZoneData.fromJson(Map<String, dynamic> json) {
    return RoomZoneData(
      id: json['id'] as String? ?? 'room',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      w: (json['w'] as num?)?.toDouble() ?? 0,
      h: (json['h'] as num?)?.toDouble() ?? 0,
      cameraMinX: (json['camera_min_x'] as num?)?.toDouble() ?? (json['cameraMinX'] as num?)?.toDouble() ?? 0,
      cameraMinY: (json['camera_min_y'] as num?)?.toDouble() ?? (json['cameraMinY'] as num?)?.toDouble() ?? 0,
      cameraMaxX: (json['camera_max_x'] as num?)?.toDouble() ?? (json['cameraMaxX'] as num?)?.toDouble() ?? 0,
      cameraMaxY: (json['camera_max_y'] as num?)?.toDouble() ?? (json['cameraMaxY'] as num?)?.toDouble() ?? 0,
      targetSceneId: json['target_scene_id'] as String? ?? json['targetSceneId'] as String?,
    );
  }

  RoomZoneData copyWith({
    String? id,
    double? x,
    double? y,
    double? w,
    double? h,
    double? cameraMinX,
    double? cameraMinY,
    double? cameraMaxX,
    double? cameraMaxY,
    String? targetSceneId,
    bool clearTargetSceneId = false,
  }) {
    return RoomZoneData(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      cameraMinX: cameraMinX ?? this.cameraMinX,
      cameraMinY: cameraMinY ?? this.cameraMinY,
      cameraMaxX: cameraMaxX ?? this.cameraMaxX,
      cameraMaxY: cameraMaxY ?? this.cameraMaxY,
      targetSceneId: clearTargetSceneId ? null : (targetSceneId ?? this.targetSceneId),
    );
  }
}

class ScenePhysicsSettings {
  final double? gravityY;
  final int velocityIterations;
  final int positionIterations;

  const ScenePhysicsSettings({
    this.gravityY,
    this.velocityIterations = 8,
    this.positionIterations = 3,
  });

  Map<String, dynamic> toJson() => {
        if (gravityY != null) 'gravityY': gravityY,
        'velocityIterations': velocityIterations,
        'positionIterations': positionIterations,
      };

  factory ScenePhysicsSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ScenePhysicsSettings();
    return ScenePhysicsSettings(
      gravityY: (json['gravityY'] as num?)?.toDouble(),
      velocityIterations: (json['velocityIterations'] as num?)?.toInt() ?? 8,
      positionIterations: (json['positionIterations'] as num?)?.toInt() ?? 3,
    );
  }
}


enum CollaboratorRole {
  owner,
  editor,
  viewer;

  static CollaboratorRole fromString(String? s) {
    switch (s) {
      case 'owner':
        return CollaboratorRole.owner;
      case 'viewer':
        return CollaboratorRole.viewer;
      default:
        return CollaboratorRole.editor;
    }
  }

  String toJsonValue() => name;
}

class CollaborationSession {
  final String sessionId;
  final String projectId;
  final String? shareBaseUrl;
  final CollaboratorRole localRole;
  final int? heartbeatSeconds;

  const CollaborationSession({
    required this.sessionId,
    required this.projectId,
    this.shareBaseUrl,
    this.localRole = CollaboratorRole.editor,
    this.heartbeatSeconds,
  });

  String shareUrl(String path) {
    final base = shareBaseUrl ?? '';
    if (base.isEmpty) return path;
    final sep = base.contains('?') ? '&' : '?';
    return '$base$sep${path.startsWith('/') ? path.substring(1) : path}';
  }

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'projectId': projectId,
        'shareBaseUrl': shareBaseUrl,
        'localRole': localRole.toJsonValue(),
        'heartbeatSeconds': heartbeatSeconds,
      };

  factory CollaborationSession.fromJson(Map<String, dynamic> json) {
    return CollaborationSession(
      sessionId: json['sessionId'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      shareBaseUrl: json['shareBaseUrl'] as String?,
      localRole: CollaboratorRole.fromString(json['localRole'] as String?),
      heartbeatSeconds: (json['heartbeatSeconds'] as num?)?.toInt(),
    );
  }
}

class ScenePatchOp {
  final String op;
  final Map<String, dynamic> payload;

  const ScenePatchOp({required this.op, required this.payload});

  Map<String, dynamic> toJson() => {'op': op, 'payload': payload};

  factory ScenePatchOp.fromJson(Map<String, dynamic> json) {
    return ScenePatchOp(
      op: json['op'] as String? ?? 'noop',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

class ScenePatch {
  final String sceneId;
  final int baseRevision;
  final List<ScenePatchOp> ops;

  const ScenePatch({
    required this.sceneId,
    required this.baseRevision,
    required this.ops,
  });

  Map<String, dynamic> toJson() => {
        'sceneId': sceneId,
        'baseRevision': baseRevision,
        'ops': ops.map((o) => o.toJson()).toList(),
      };

  factory ScenePatch.fromJson(Map<String, dynamic> json) {
    return ScenePatch(
      sceneId: json['sceneId'] as String? ?? '',
      baseRevision: (json['baseRevision'] as num?)?.toInt() ?? 0,
      ops: (json['ops'] as List? ?? [])
          .map((e) => ScenePatchOp.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}


class ProjectAsset {
  final String id;
  final String name;
  final String type;
  final String path;
  final DateTime createdAt;
  final DateTime modifiedAt;
  dynamic data;
  SpriteAssetMeta? spriteMeta;

  ProjectAsset({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    required this.createdAt,
    required this.modifiedAt,
    this.data,
    this.spriteMeta,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        if (spriteMeta != null) 'spriteMeta': spriteMeta!.toJson(),
      };

  factory ProjectAsset.fromJson(Map<String, dynamic> json) {
    SpriteAssetMeta? meta;
    if (json['spriteMeta'] != null) {
      meta = SpriteAssetMeta.fromJson(json['spriteMeta'] as Map<String, dynamic>);
    }
    return ProjectAsset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      path: json['path'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      modifiedAt: DateTime.parse(json['modifiedAt'] ?? DateTime.now().toIso8601String()),
      spriteMeta: meta,
    );
  }
}


class SceneObject {
  final String id;
  final String name;
  final String assetId;
  final double x;
  final double y;
  final double z;
  final double width;
  final double height;
  final double rotation;
  final double scaleX;
  final double scaleY;
  final double originX;
  final double originY;
  final bool active;
  final bool visible;
  final bool locked;
  final String? layerId;
  final String? parentId;
  final String? prefabId;
  final Map<String, dynamic> propertyOverrides;
  final Map<String, dynamic> properties;
  final String? scriptId;

  SceneObject({
    required this.id,
    required this.name,
    required this.assetId,
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.width = 40,
    this.height = 40,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
    this.originX = 0.5,
    this.originY = 0.5,
    this.active = true,
    this.visible = true,
    this.locked = false,
    this.layerId,
    this.parentId,
    this.prefabId,
    this.propertyOverrides = const {},
    this.properties = const {},
    this.scriptId,
  });

  SceneObject copyWith({
    String? id,
    String? name,
    String? assetId,
    double? x,
    double? y,
    double? z,
    double? width,
    double? height,
    double? rotation,
    double? scaleX,
    double? scaleY,
    double? originX,
    double? originY,
    bool? active,
    bool? visible,
    bool? locked,
    String? layerId,
    String? parentId,
    bool clearParentId = false,
    String? prefabId,
    Map<String, dynamic>? propertyOverrides,
    Map<String, dynamic>? properties,
    String? scriptId,
  }) {
    return SceneObject(
      id: id ?? this.id,
      name: name ?? this.name,
      assetId: assetId ?? this.assetId,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      originX: originX ?? this.originX,
      originY: originY ?? this.originY,
      active: active ?? this.active,
      visible: visible ?? this.visible,
      locked: locked ?? this.locked,
      layerId: layerId ?? this.layerId,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      prefabId: prefabId ?? this.prefabId,
      propertyOverrides: propertyOverrides ?? this.propertyOverrides,
      properties: properties ?? this.properties,
      scriptId: scriptId ?? this.scriptId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assetId': assetId,
        'x': x,
        'y': y,
        'z': z,
        'width': width,
        'height': height,
        'rotation': rotation,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'originX': originX,
        'originY': originY,
        'active': active,
        'visible': visible,
        'locked': locked,
        'layerId': layerId,
        'parentId': parentId,
        'prefabId': prefabId,
        'propertyOverrides': propertyOverrides,
        'properties': properties,
        'scriptId': scriptId,
      };

  factory SceneObject.fromJson(Map<String, dynamic> json) {
    return SceneObject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      assetId: json['assetId'] ?? '',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      z: (json['z'] ?? 0).toDouble(),
      width: (json['width'] ?? 40).toDouble(),
      height: (json['height'] ?? 40).toDouble(),
      rotation: (json['rotation'] ?? 0).toDouble(),
      scaleX: (json['scaleX'] ?? 1).toDouble(),
      scaleY: (json['scaleY'] ?? 1).toDouble(),
      originX: (json['originX'] ?? 0.5).toDouble(),
      originY: (json['originY'] ?? 0.5).toDouble(),
      active: json['active'] as bool? ?? true,
      visible: json['visible'] as bool? ?? true,
      locked: json['locked'] as bool? ?? false,
      layerId: json['layerId'] as String?,
      parentId: json['parentId'] as String?,
      prefabId: json['prefabId'] as String?,
      propertyOverrides: (json['propertyOverrides'] as Map?)?.cast<String, dynamic>() ?? {},
      properties: (json['properties'] as Map?)?.cast<String, dynamic>() ?? {},
      scriptId: json['scriptId'] as String?,
    );
  }
}


class Scene {
  final String id;
  String name;
  List<SceneObject> objects;
  List<SceneLayer> layers;
  SceneCamera camera;
  int backgroundColorArgb;
  ScenePhysicsSettings physics;
  List<TilemapLayerData> tilemaps;
  List<RoomZoneData> rooms;
  DateTime createdAt;
  DateTime modifiedAt;
  int revision;
  int? cloudRevision;
  CollaborationSession? collaboration;
  Map<String, dynamic> extensions;

  Scene({
    required this.id,
    required this.name,
    this.objects = const [],
    List<SceneLayer>? layers,
    SceneCamera? camera,
    this.backgroundColorArgb = 0xFF212121,
    ScenePhysicsSettings? physics,
    this.tilemaps = const [],
    this.rooms = const [],
    required this.createdAt,
    required this.modifiedAt,
    this.revision = 0,
    this.cloudRevision,
    this.collaboration,
    Map<String, dynamic>? extensions,
  })  : layers = layers ?? Scene.defaultLayers(),
        extensions = extensions ?? <String, dynamic>{},
        camera = camera ?? const SceneCamera(),
        physics = physics ?? const ScenePhysicsSettings();

  static List<SceneLayer> defaultLayers() => [
        const SceneLayer(
          id: SceneLayer.defaultLayerId,
          name: 'Default',
          sortOrder: 0,
        ),
        const SceneLayer(
          id: SceneLayer.uiLayerId,
          name: 'UI',
          sortOrder: 1000,
        ),
      ];

  Map<String, dynamic> toJson() => {
        'formatVersion': kSceneFormatVersion,
        'id': id,
        'name': name,
        'objects': objects.map((o) => o.toJson()).toList(),
        'layers': layers.map((l) => l.toJson()).toList(),
        'camera': camera.toJson(),
        'backgroundColorArgb': backgroundColorArgb,
        'physics': physics.toJson(),
        'tilemaps': tilemaps
            .map((l) => {
                  'id': l.id,
                  'tileW': l.tileW,
                  'tileH': l.tileH,
                  'zOrder': l.zOrder,
                  'visible': l.visible,
                  if (l.tilesetId != null && l.tilesetId!.isNotEmpty) 'tilesetId': l.tilesetId,
                  'autotile': l.autotile,
                  'chunks': l.chunks
                      .map((c) => {
                            'cx': c.cx,
                            'cy': c.cy,
                            'tw': c.tw,
                            'th': c.th,
                            'tile_ids': c.tileIds,
                            'collision': c.collision,
                          })
                      .toList(),
                })
            .toList(),
        'rooms': rooms
            .map((r) => {
                  'id': r.id,
                  'x': r.x,
                  'y': r.y,
                  'w': r.w,
                  'h': r.h,
                  'cameraMinX': r.cameraMinX,
                  'cameraMinY': r.cameraMinY,
                  'cameraMaxX': r.cameraMaxX,
                  'cameraMaxY': r.cameraMaxY,
                })
            .toList(),
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'revision': revision,
        if (cloudRevision != null) 'cloudRevision': cloudRevision,
        if (collaboration != null) 'collaboration': collaboration!.toJson(),
        if (extensions.isNotEmpty) 'extensions': extensions,
      };

  factory Scene.fromJson(Map<String, dynamic> json) {
    final ver = (json['formatVersion'] as num?)?.toInt() ?? 1;
    List<SceneLayer> layers;
    if (json['layers'] is List && (json['layers'] as List).isNotEmpty) {
      layers = (json['layers'] as List)
          .map((e) => SceneLayer.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      layers = Scene.defaultLayers();
    }
    final layerIds = layers.map((l) => l.id).toSet();
    var objects = (json['objects'] as List? ?? [])
        .map((o) => SceneObject.fromJson(o as Map<String, dynamic>))
        .toList();
    if (ver < 2) {
      objects = objects
          .map((o) => o.layerId == null || !layerIds.contains(o.layerId)
              ? o.copyWith(layerId: SceneLayer.defaultLayerId)
              : o)
          .toList();
    }
    final tmRaw = json['tilemaps'] as List? ?? [];
    final tilemaps = tmRaw.map((e) => TilemapLayerData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    final rmRaw = json['rooms'] as List? ?? [];
    final rooms = rmRaw.map((e) => RoomZoneData.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    SceneCamera camera;
    if (json['camera'] is Map) {
      camera = SceneCamera.fromJson(json['camera'] as Map<String, dynamic>);
    } else if (json['cameras'] is List && (json['cameras'] as List).isNotEmpty) {
      final c0 = Map<String, dynamic>.from((json['cameras'] as List).first as Map);
      camera = SceneCamera(
        x: (c0['x'] as num?)?.toDouble() ?? 0,
        y: (c0['y'] as num?)?.toDouble() ?? 0,
        zoom: (c0['zoom'] as num?)?.toDouble() ?? 1,
      );
    } else {
      camera = SceneCamera.fromJson(null);
    }

    return Scene(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Untitled',
      objects: objects,
      layers: layers,
      camera: camera,
      backgroundColorArgb: (json['backgroundColorArgb'] as num?)?.toInt() ?? 0xFF212121,
      physics: ScenePhysicsSettings.fromJson(json['physics'] as Map<String, dynamic>?),
      tilemaps: tilemaps,
      rooms: rooms,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      modifiedAt: DateTime.parse(json['modifiedAt'] ?? DateTime.now().toIso8601String()),
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      cloudRevision: (json['cloudRevision'] as num?)?.toInt(),
      collaboration: json['collaboration'] != null
          ? CollaborationSession.fromJson(json['collaboration'] as Map<String, dynamic>)
          : null,
      extensions: json['extensions'] is Map
          ? Map<String, dynamic>.from(json['extensions'] as Map)
          : null,
    );
  }

  void bumpRevision() {
    revision++;
    modifiedAt = DateTime.now();
  }
}

List<SceneObject> sceneObjectsPaintOrder(Scene scene) {
  int layerRank(String? layerId) {
    final id = layerId ?? SceneLayer.defaultLayerId;
    for (final l in scene.layers) {
      if (l.id == id) return l.sortOrder;
    }
    return 0;
  }

  final indexed = List.generate(scene.objects.length, (i) => i);
  indexed.sort((ai, bi) {
    final a = scene.objects[ai];
    final b = scene.objects[bi];
    final lr = layerRank(a.layerId).compareTo(layerRank(b.layerId));
    if (lr != 0) return lr;
    final zr = a.z.compareTo(b.z);
    if (zr != 0) return zr;
    return ai.compareTo(bi);
  });
  return indexed.map((i) => scene.objects[i]).toList();
}

List<SceneObject> instantiateAllFromPrefab(
  PrefabDefinition def, {
  String? layerId,
  String? name,
}) {
  final rnd = math.Random();
  String nid() =>
      'inst_${DateTime.now().millisecondsSinceEpoch}_${rnd.nextInt(0x7fffffff)}';

  final idMap = <String, String>{def.templateRoot.id: nid()};
  for (final c in def.children) {
    idMap[c.id] = nid();
  }

  final defaultLayer = layerId ??
      def.templateRoot.layerId ??
      SceneLayer.defaultLayerId;

  SceneObject remap(SceneObject o) {
    final newId = idMap[o.id]!;
    final pid = o.parentId;
    final newPid = pid == null ? null : idMap[pid];
    return o.copyWith(
      id: newId,
      name: o.id == def.templateRoot.id ? (name ?? o.name) : o.name,
      parentId: newPid,
      clearParentId: newPid == null && pid != null,
      prefabId: def.id,
      layerId: layerId ?? o.layerId ?? defaultLayer,
    );
  }

  final root = remap(def.templateRoot);
  final mappedKids = def.children.map(remap).toList();
  final sorted = <SceneObject>[root];
  final rest = List<SceneObject>.from(mappedKids);
  while (rest.isNotEmpty) {
    final i = rest.indexWhere((c) => sorted.any((s) => s.id == c.parentId));
    if (i < 0) {
      sorted.addAll(rest);
      break;
    }
    sorted.add(rest.removeAt(i));
  }
  return sorted;
}

SceneObject instantiateFromPrefab(
  PrefabDefinition def, {
  String? layerId,
  String? name,
}) {
  return instantiateAllFromPrefab(def, layerId: layerId, name: name).first;
}

Scene? applyScenePatch(Scene scene, ScenePatch patch) {
  if (patch.baseRevision != scene.revision) return null;
  var objects = List<SceneObject>.from(scene.objects);
  var layers = List<SceneLayer>.from(scene.layers);

  for (final o in patch.ops) {
    switch (o.op) {
      case 'addObject':
        final raw = o.payload['object'] as Map<String, dynamic>?;
        if (raw != null) objects.add(SceneObject.fromJson(raw));
        break;
      case 'removeObject':
        final id = o.payload['id'] as String?;
        if (id != null) objects.removeWhere((e) => e.id == id);
        break;
      case 'updateObject':
        final id = o.payload['id'] as String?;
        if (id == null) break;
        final idx = objects.indexWhere((e) => e.id == id);
        if (idx < 0) break;
        final cur = objects[idx];
        final nx = (o.payload['x'] as num?)?.toDouble();
        final ny = (o.payload['y'] as num?)?.toDouble();
        final nz = (o.payload['z'] as num?)?.toDouble();
        objects[idx] = cur.copyWith(
          x: nx,
          y: ny,
          z: nz,
          name: o.payload['name'] as String?,
          layerId: o.payload['layerId'] as String?,
          parentId: o.payload['parentId'] as String?,
          active: o.payload['active'] as bool?,
          visible: o.payload['visible'] as bool?,
          locked: o.payload['locked'] as bool?,
        );
        break;
      case 'setLayers':
        final raw = o.payload['layers'] as List?;
        if (raw != null) {
          layers = raw.map((e) => SceneLayer.fromJson(e as Map<String, dynamic>)).toList();
        }
        break;
      default:
        break;
    }
  }

  return Scene(
    id: scene.id,
    name: scene.name,
    objects: objects,
    layers: layers,
    camera: scene.camera,
    backgroundColorArgb: scene.backgroundColorArgb,
    physics: scene.physics,
    tilemaps: scene.tilemaps,
    rooms: scene.rooms,
    createdAt: scene.createdAt,
    modifiedAt: DateTime.now(),
    revision: scene.revision + 1,
    cloudRevision: scene.cloudRevision,
    collaboration: scene.collaboration,
  );
}
