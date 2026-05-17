import 'dart:convert';

class PlayLoadResult {
  final String? error;
  final String? rustSceneJson;
  final Map<String, dynamic> playBootstrap;
  const PlayLoadResult({
    this.error,
    this.rustSceneJson,
    this.playBootstrap = const {},
  });
}

Future<PlayLoadResult> loadPlayPayload(
  String? projectPath, {
  bool freshPlay = false,
}) async {
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
        'sprite': {
          'color_hex': 0xFF2E7D32,
          'texture_path': null,
        },
        'physics': null,
        'script': null,
        'visible': true,
        'on_ground': false,
      },
      {
        'id': 1,
        'name': 'Player',
        'transform': {
          'pos': {'x': 640.0, 'y': 400.0},
          'size': {'x': 48.0, 'y': 64.0},
          'rot': 0.0,
        },
        'sprite': {
          'color_hex': 0xFFE65100,
          'texture_path': null,
        },
        'physics': {
          'velocity': {'x': 0.0, 'y': 0.0},
          'mass': 1.0,
          'is_static': false,
          'use_gravity': true,
          'bounciness': 0.05,
          'shape': 'aabb',
          'collision_layer': 1,
          'collision_mask': 0xFFFF,
          'is_trigger': false,
        },
        'script': {'code': 'web'},
        'visible': true,
        'on_ground': false,
      },
    ],
    'next_id': 2,
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
