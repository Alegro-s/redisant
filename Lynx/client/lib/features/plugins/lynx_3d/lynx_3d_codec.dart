import '../../engine/models/engine_models.dart';
import '../../engine/runtime/lynx_windows_3d_runtime.dart';
import '../lynx_plugin_contract.dart';
import '../lynx_plugin_manifest.dart';

/// Парсинг `extensions.lynx.3d` и `properties.lynx.3d` (волна 6).
class Lynx3dSceneExtension {
  final bool active;
  final List<double> gravity;
  final String ambientColor;
  final Lynx3dCameraSettings camera;
  final Lynx3dRoom? room;
  final Lynx3dTerrainSpec? terrain;
  final List<Lynx3dObjectSpec> objects;
  final Lynx3dCullingSpec culling;
  final Lynx3dRenderSpec render;
  final List<Lynx3dPhysicsJointSpec> physicsJoints;

  const Lynx3dSceneExtension({
    required this.active,
    required this.gravity,
    required this.ambientColor,
    required this.camera,
    this.room,
    this.terrain,
    this.objects = const [],
    this.culling = const Lynx3dCullingSpec(),
    this.render = const Lynx3dRenderSpec(),
    this.physicsJoints = const [],
  });

  static Lynx3dSceneExtension? fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final active = raw['active'] as bool? ?? true;
    if (!active) return null;
    final world = raw['world'] as Map?;
    final grav = (world?['gravity'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [0, -9.81, 0];
    final ambient = world?['ambientColor'] as String? ?? '#404050';
    final cullRaw = world?['culling'] is Map
        ? Map<String, dynamic>.from(world!['culling'] as Map)
        : null;
    final camRaw = raw['camera'] is Map
        ? Map<String, dynamic>.from(raw['camera'] as Map)
        : null;
    final roomRaw = raw['room'] is Map
        ? Map<String, dynamic>.from(raw['room'] as Map)
        : null;
    final terrainRaw = raw['terrain'] is Map
        ? Map<String, dynamic>.from(raw['terrain'] as Map)
        : null;
    final objsRaw = raw['objects'] as List?;
    final jointsRaw = raw['physicsJoints'] as List?;
    final renderRaw = world?['render'] is Map
        ? Map<String, dynamic>.from(world!['render'] as Map)
        : null;
    return Lynx3dSceneExtension(
      active: active,
      gravity: grav.length >= 3 ? grav : [0, -9.81, 0],
      ambientColor: ambient,
      camera: Lynx3dCameraSettings.fromMap(camRaw),
      room: roomRaw != null ? Lynx3dRoom.fromMap(roomRaw) : null,
      terrain:
          terrainRaw != null ? Lynx3dTerrainSpec.fromMap(terrainRaw) : null,
      objects: objsRaw
              ?.map((e) => Lynx3dObjectSpec.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      culling: Lynx3dCullingSpec.fromMap(cullRaw),
      render: Lynx3dRenderSpec.fromMap(renderRaw),
      physicsJoints: jointsRaw
              ?.map((e) =>
                  Lynx3dPhysicsJointSpec.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'active': active,
        'world': {
          'ambientColor': ambientColor,
          'gravity': gravity,
          if (!culling.isDefault) 'culling': culling.toMap(),
          if (!render.isDefault) 'render': render.toMap(),
        },
        'camera': camera.toMap(),
        if (room != null) 'room': room!.toMap(),
        if (terrain != null) 'terrain': terrain!.toMap(),
        if (physicsJoints.isNotEmpty)
          'physicsJoints': physicsJoints.map((j) => j.toMap()).toList(),
        if (objects.isNotEmpty)
          'objects': objects.map((o) => o.toMap()).toList(),
      };
}

class Lynx3dRenderSpec {
  final double iblStrength;
  final bool postEnabled;
  final double exposure;
  final double bloom;

  const Lynx3dRenderSpec({
    this.iblStrength = 0.35,
    this.postEnabled = true,
    this.exposure = 1.0,
    this.bloom = 0.12,
  });

  factory Lynx3dRenderSpec.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Lynx3dRenderSpec();
    return Lynx3dRenderSpec(
      iblStrength: (m['iblStrength'] as num?)?.toDouble() ?? 0.35,
      postEnabled: m['postEnabled'] as bool? ?? true,
      exposure: (m['exposure'] as num?)?.toDouble() ?? 1.0,
      bloom: (m['bloom'] as num?)?.toDouble() ?? 0.12,
    );
  }

  Map<String, dynamic> toMap() => {
        'iblStrength': iblStrength,
        'postEnabled': postEnabled,
        'exposure': exposure,
        'bloom': bloom,
      };

  bool get isDefault =>
      iblStrength == 0.35 &&
      postEnabled &&
      exposure == 1.0 &&
      bloom == 0.12;
}

class Lynx3dPhysicsJointSpec {
  final String type;
  final String bodyA;
  final String bodyB;
  final List<double> anchor;
  final List<double> axis;
  final double minAngleDeg;
  final double maxAngleDeg;

  const Lynx3dPhysicsJointSpec({
    this.type = 'hinge',
    required this.bodyA,
    required this.bodyB,
    this.anchor = const [0, 1, 0],
    this.axis = const [0, 1, 0],
    this.minAngleDeg = -45,
    this.maxAngleDeg = 45,
  });

  factory Lynx3dPhysicsJointSpec.fromMap(Map<String, dynamic> m) {
    List<double> v3(List? l, List<double> d) {
      if (l == null || l.length < 3) return d;
      return l.map((e) => (e as num).toDouble()).toList();
    }

    return Lynx3dPhysicsJointSpec(
      type: m['type'] as String? ?? 'hinge',
      bodyA: m['bodyA'] as String? ?? '',
      bodyB: m['bodyB'] as String? ?? '',
      anchor: v3(m['anchor'] as List?, const [0, 1, 0]),
      axis: v3(m['axis'] as List?, const [0, 1, 0]),
      minAngleDeg: (m['minAngleDeg'] as num?)?.toDouble() ?? -45,
      maxAngleDeg: (m['maxAngleDeg'] as num?)?.toDouble() ?? 45,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'bodyA': bodyA,
        'bodyB': bodyB,
        'anchor': anchor,
        'axis': axis,
        'minAngleDeg': minAngleDeg,
        'maxAngleDeg': maxAngleDeg,
      };
}

class Lynx3dTerrainSpec {
  final String heightmap;
  final List<double> size;
  final List<double> center;
  final int segments;
  final int maxLod;
  final double lodSplitDistance;
  final int clipmapLevels;
  final Lynx3dMaterialSpec material;

  const Lynx3dTerrainSpec({
    required this.heightmap,
    this.size = const [32, 4, 32],
    this.center = const [0, 0, 0],
    this.segments = 32,
    this.maxLod = 2,
    this.lodSplitDistance = 12,
    this.clipmapLevels = 1,
    this.material = const Lynx3dMaterialSpec(),
  });

  factory Lynx3dTerrainSpec.fromMap(Map<String, dynamic> m) {
    List<double> vec3(List? l, List<double> def) {
      if (l == null || l.length < 3) return def;
      return l.map((e) => (e as num).toDouble()).toList();
    }

    final matRaw = m['material'] is Map
        ? Map<String, dynamic>.from(m['material'] as Map)
        : null;
    return Lynx3dTerrainSpec(
      heightmap: m['heightmap'] as String? ?? '',
      size: vec3(m['size'] as List?, [32, 4, 32]),
      center: vec3(m['center'] as List?, [0, 0, 0]),
      segments: (m['segments'] as num?)?.toInt() ?? 32,
      maxLod: (m['maxLod'] as num?)?.toInt() ?? 2,
      lodSplitDistance: (m['lodSplitDistance'] as num?)?.toDouble() ?? 12,
      clipmapLevels: (m['clipmapLevels'] as num?)?.toInt() ?? 1,
      material: Lynx3dMaterialSpec.fromMap(matRaw),
    );
  }

  Map<String, dynamic> toMap() => {
        'heightmap': heightmap,
        'size': size,
        'center': center,
        'segments': segments,
        'maxLod': maxLod,
        if (lodSplitDistance != 12) 'lodSplitDistance': lodSplitDistance,
        if (clipmapLevels != 1) 'clipmapLevels': clipmapLevels,
        if (material.metallic != null ||
            material.roughness != null ||
            material.albedoTexture != null ||
            material.metallicRoughnessTexture != null)
          'material': material.toMap(),
      };
}

class Lynx3dCameraSettings {
  final String type;
  final double fovY;
  final double near;
  final double far;
  final double orbitDistance;

  const Lynx3dCameraSettings({
    this.type = 'perspective',
    this.fovY = 60,
    this.near = 0.1,
    this.far = 500,
    this.orbitDistance = 12,
  });

  factory Lynx3dCameraSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Lynx3dCameraSettings();
    return Lynx3dCameraSettings(
      type: m['type'] as String? ?? 'perspective',
      fovY: (m['fovY'] as num?)?.toDouble() ?? 60,
      near: (m['near'] as num?)?.toDouble() ?? 0.1,
      far: (m['far'] as num?)?.toDouble() ?? 500,
      orbitDistance: (m['orbitDistance'] as num?)?.toDouble() ?? 12,
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'fovY': fovY,
        'near': near,
        'far': far,
        'orbitDistance': orbitDistance,
      };
}

/// Runtime body для Play / physics sync (M14a).
class Lynx3dRuntimeBody {
  Lynx3dRuntimeBody(Lynx3dObjectSpec spec)
      : spec = spec,
        position = List<double>.from(spec.position),
        velocity = [0, 0, 0];

  final Lynx3dObjectSpec spec;
  List<double> position;
  List<double> velocity;
}

class Lynx3dRoom {
  final double width;
  final double height;
  final double depth;
  final List<double> center;

  const Lynx3dRoom({
    this.width = 8,
    this.height = 4,
    this.depth = 8,
    this.center = const [0, 2, 0],
  });

  factory Lynx3dRoom.fromMap(Map<String, dynamic> m) {
    final c = (m['center'] as List?)?.map((e) => (e as num).toDouble()).toList();
    return Lynx3dRoom(
      width: (m['width'] as num?)?.toDouble() ?? 8,
      height: (m['height'] as num?)?.toDouble() ?? 4,
      depth: (m['depth'] as num?)?.toDouble() ?? 8,
      center: c != null && c.length >= 3 ? c : [0, 2, 0],
    );
  }

  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
        'depth': depth,
        'center': center,
      };
}

class Lynx3dMaterialSpec {
  final double? metallic;
  final double? roughness;
  final String? albedoTexture;
  final String? normalTexture;
  final String? metallicRoughnessTexture;

  const Lynx3dMaterialSpec({
    this.metallic,
    this.roughness,
    this.albedoTexture,
    this.normalTexture,
    this.metallicRoughnessTexture,
  });

  factory Lynx3dMaterialSpec.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Lynx3dMaterialSpec();
    return Lynx3dMaterialSpec(
      metallic: (m['metallic'] as num?)?.toDouble(),
      roughness: (m['roughness'] as num?)?.toDouble(),
      albedoTexture: m['albedoTexture'] as String?,
      normalTexture: m['normalTexture'] as String?,
      metallicRoughnessTexture: m['metallicRoughnessTexture'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        if (metallic != null) 'metallic': metallic,
        if (roughness != null) 'roughness': roughness,
        if (albedoTexture != null) 'albedoTexture': albedoTexture,
        if (normalTexture != null) 'normalTexture': normalTexture,
        if (metallicRoughnessTexture != null)
          'metallicRoughnessTexture': metallicRoughnessTexture,
      };
}

class Lynx3dObjectSpec {
  final String id;
  final String? mesh;
  final List<double> position;
  final List<double> rotationEuler;
  final List<double> scale;
  final List<double> halfExtents;
  final int colorArgb;
  final Lynx3dMaterialSpec material;
  /// GLTF clip name (M13a); Core CPU skinning on Windows forward path.
  final String? animationClip;
  final double animationTime;
  final Lynx3dPhysicsSpec physics;

  const Lynx3dObjectSpec({
    required this.id,
    this.mesh,
    this.position = const [0, 1, 0],
    this.rotationEuler = const [0, 0, 0],
    this.scale = const [1, 1, 1],
    this.halfExtents = const [0.5, 0.5, 0.5],
    this.colorArgb = 0xFF8D6E63,
    this.material = const Lynx3dMaterialSpec(),
    this.animationClip,
    this.animationTime = 0,
    this.physics = const Lynx3dPhysicsSpec(),
  });

  factory Lynx3dObjectSpec.fromMap(Map<String, dynamic> m) {
    List<double> vec3(List? l, List<double> def) {
      if (l == null || l.length < 3) return def;
      return l.map((e) => (e as num).toDouble()).toList();
    }

    final t = m['transform'] as Map?;
    final matRaw = m['material'] is Map
        ? Map<String, dynamic>.from(m['material'] as Map)
        : null;
    return Lynx3dObjectSpec(
      id: m['id'] as String? ?? m['sceneObjectId'] as String? ?? 'obj',
      mesh: m['mesh'] as String?,
      position: vec3(t?['position'] as List?, vec3(m['position'] as List?, [0, 1, 0])),
      rotationEuler: vec3(
        t?['rotationEuler'] as List?,
        vec3(m['rotationEuler'] as List?, [0, 0, 0]),
      ),
      scale: vec3(t?['scale'] as List?, vec3(m['scale'] as List?, [1, 1, 1])),
      halfExtents: vec3(m['halfExtents'] as List?, [0.5, 0.5, 0.5]),
      colorArgb: _parseColor(m['color'] ?? m['colorArgb']),
      material: Lynx3dMaterialSpec.fromMap(matRaw),
      animationClip: m['animationClip'] as String?,
      animationTime: (m['animationTime'] as num?)?.toDouble() ?? 0,
      physics: Lynx3dPhysicsSpec.fromMap(
        m['physics'] is Map ? Map<String, dynamic>.from(m['physics'] as Map) : null,
      ),
    );
  }

  static int _parseColor(dynamic v) {
    if (v is int) return v;
    if (v is String && v.startsWith('#') && v.length >= 7) {
      final hex = v.substring(1);
      final n = int.tryParse(hex.length > 6 ? hex.substring(0, 6) : hex, radix: 16);
      if (n != null) return 0xFF000000 | n;
    }
    return 0xFF8D6E63;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        if (mesh != null) 'mesh': mesh,
        'transform': {
          'position': position,
          'rotationEuler': rotationEuler,
          'scale': scale,
        },
        'halfExtents': halfExtents,
        'colorArgb': colorArgb,
        if (material.metallic != null ||
            material.roughness != null ||
            material.albedoTexture != null ||
            material.metallicRoughnessTexture != null)
          'material': material.toMap(),
        if (animationClip != null) 'animationClip': animationClip,
        if (animationTime != 0) 'animationTime': animationTime,
        if (physics.bodyType != 'dynamic' ||
            physics.restitution != 0.15 ||
            physics.friction != 0.55)
          'physics': physics.toMap(),
      };
}

/// M14b: frustum + CPU Hi-Z (Core `cull3d`).
class Lynx3dCullingSpec {
  final bool frustum;
  final bool hiZ;
  final int hiZSize;

  const Lynx3dCullingSpec({
    this.frustum = true,
    this.hiZ = true,
    this.hiZSize = 64,
  });

  factory Lynx3dCullingSpec.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Lynx3dCullingSpec();
    return Lynx3dCullingSpec(
      frustum: m['frustum'] as bool? ?? true,
      hiZ: m['hiZ'] as bool? ?? true,
      hiZSize: (m['hiZSize'] as num?)?.toInt() ?? 64,
    );
  }

  Map<String, dynamic> toMap() => {
        'frustum': frustum,
        'hiZ': hiZ,
        if (hiZSize != 64) 'hiZSize': hiZSize,
      };

  bool get isDefault => frustum && hiZ && hiZSize == 64;
}

class Lynx3dPhysicsSpec {
  final String bodyType;
  final double restitution;
  final double friction;

  const Lynx3dPhysicsSpec({
    this.bodyType = 'dynamic',
    this.restitution = 0.15,
    this.friction = 0.55,
  });

  bool get isStatic => bodyType == 'static';

  factory Lynx3dPhysicsSpec.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const Lynx3dPhysicsSpec();
    return Lynx3dPhysicsSpec(
      bodyType: m['bodyType'] as String? ?? 'dynamic',
      restitution: (m['restitution'] as num?)?.toDouble() ?? 0.15,
      friction: (m['friction'] as num?)?.toDouble() ?? 0.55,
    );
  }

  Map<String, dynamic> toMap() => {
        'bodyType': bodyType,
        'restitution': restitution,
        'friction': friction,
      };
}

Lynx3dObjectSpec? lynx3dFromSceneObject(SceneObject o) {
  final block = o.properties[Lynx3dPluginIds.objectPropertyKey];
  if (block is! Map) return null;
  final m = Map<String, dynamic>.from(block);
  m['id'] = o.id;
  if (m['mesh'] == null && o.assetId != null && o.assetId!.isNotEmpty) {
    m['mesh'] = o.assetId;
  }
  return Lynx3dObjectSpec.fromMap(m);
}

Map<String, dynamic> defaultObject3dProperties({
  String? mesh,
  List<double>? position,
}) =>
    {
      'mesh': mesh ?? 'assets/models/crate.glb',
      'transform': {
        'position': position ?? [0, 1, 0],
        'rotationEuler': [0, 0, 0],
        'scale': [1, 1, 1],
      },
      'halfExtents': [0.5, 0.5, 0.5],
      'color': '#8D6E63',
    };

/// Данные для Play bootstrap (`playBootstrap['lynx3d']`).
Map<String, dynamic>? lynx3dPlayBootstrapFromScene(
  Scene scene, {
  bool physics = true,
  LynxWindows3dRuntime? windows3dRuntime,
  LynxProjectMode projectMode = LynxProjectMode.d2,
  bool plugin3dEnabled = false,
}) {
  if (projectMode == LynxProjectMode.d2 && !plugin3dEnabled) return null;
  final ext = build3dExtensionFromScene(scene, null, includeDefaults: plugin3dEnabled);
  if (!ext.active && ext.objects.isEmpty && ext.room == null && ext.terrain == null) {
    return null;
  }
  final m = ext.toMap();
  m['simulatePhysics'] = physics;
  if (windows3dRuntime != null &&
      windows3dRuntime != LynxWindows3dRuntime.canvasPreview) {
    m['windows3dRuntime'] = windows3dRuntime.jsonValue;
  }
  return m;
}

/// Собирает extension + объекты из сцены редактора.
Lynx3dSceneExtension build3dExtensionFromScene(
  Scene scene,
  LynxPluginProjectContext? ctx, {
  bool includeDefaults = true,
}) {
  final prior = Lynx3dSceneExtension.fromMap(
    scene.extensions[Lynx3dPluginIds.sceneExtensionKey] as Map<String, dynamic>?,
  );
  final objects = <Lynx3dObjectSpec>[];
  for (final o in scene.objects) {
    final spec = lynx3dFromSceneObject(o);
    if (spec != null) objects.add(spec);
  }
  final mergedObjects = objects.isNotEmpty
      ? objects
      : (prior?.objects ?? const <Lynx3dObjectSpec>[]);
  final has3dData = (prior?.active ?? false) ||
      mergedObjects.isNotEmpty ||
      prior?.room != null ||
      prior?.terrain != null;
  if (!includeDefaults && !has3dData) {
    return const Lynx3dSceneExtension(
      active: false,
      gravity: [0, -9.81, 0],
      ambientColor: '#404050',
      camera: Lynx3dCameraSettings(),
      objects: [],
    );
  }
    return Lynx3dSceneExtension(
      active: prior?.active ?? (includeDefaults && mergedObjects.isNotEmpty),
      gravity: prior?.gravity ?? [0, -9.81, 0],
      ambientColor: prior?.ambientColor ?? '#404050',
      camera: prior?.camera ?? const Lynx3dCameraSettings(),
      room: prior?.room ??
          (includeDefaults && mergedObjects.isNotEmpty
              ? const Lynx3dRoom(width: 8, height: 4, depth: 8, center: [0, 2, 0])
              : null),
      terrain: prior?.terrain,
      render: prior?.render ?? const Lynx3dRenderSpec(),
      physicsJoints: prior?.physicsJoints ?? const [],
      objects: mergedObjects,
      culling: prior?.culling ?? const Lynx3dCullingSpec(),
    );
}
