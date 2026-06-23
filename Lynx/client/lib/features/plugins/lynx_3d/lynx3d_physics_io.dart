import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../../engine/ffi/engine_bridge.dart';
import 'lynx_3d_codec.dart';

/// M14a: 3D physics через Core `physics3d_*` FFI.
class Lynx3dPhysicsController {
  Pointer<Void>? _world;

  static bool _checked = false;
  static bool _available = false;

  static bool get isAvailable {
    if (_checked) return _available;
    _checked = true;
    if (kIsWeb) return false;
    try {
      EngineBridge.init();
      EngineBridge.lib.lookup<NativeFunction<Pointer<Void> Function()>>(
        'physics3d_world_create',
      );
      _available = true;
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  bool get isActive => _world != null && _world != nullptr;

  bool loadExtension(Lynx3dSceneExtension ext) {
    dispose();
    if (!isAvailable) return false;
    _world = _create();
    if (_world == null || _world == nullptr) return false;
    final json = jsonEncode(ext.toMap());
    final ok = _load(_world!, json);
    if (ok == 0) {
      dispose();
      return false;
    }
    return true;
  }

  bool step(double dt) {
    final w = _world;
    if (w == null || w == nullptr) return false;
    return _step(w, dt) != 0;
  }

  void syncPositions(List<Lynx3dRuntimeBody> bodies) {
    final w = _world;
    if (w == null || w == nullptr) return;
    final count = _bodyCount(w);
    final idByIndex = <String, int>{};
    for (var i = 0; i < count; i++) {
      final id = _bodyId(w, i);
      if (id != null) idByIndex[id] = i;
    }
    for (final b in bodies) {
      final idx = idByIndex[b.spec.id];
      if (idx == null) continue;
      final pos = _bodyPosition(w, idx);
      if (pos != null) {
        b.position[0] = pos[0];
        b.position[1] = pos[1];
        b.position[2] = pos[2];
      }
    }
  }

  void dispose() {
    final w = _world;
    if (w != null && w != nullptr) {
      _destroy(w);
    }
    _world = null;
  }

  static Pointer<Void>? _create() {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Pointer<Void> Function()>>('physics3d_world_create')
        .asFunction<Pointer<Void> Function()>();
    return f();
  }

  static void _destroy(Pointer<Void> w) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('physics3d_world_destroy')
        .asFunction<void Function(Pointer<Void>)>();
    f(w);
  }

  static int _load(Pointer<Void> w, String json) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Uint8 Function(Pointer<Void>, Pointer<Utf8>)>>(
          'physics3d_world_load_lynx3d',
        )
        .asFunction<int Function(Pointer<Void>, Pointer<Utf8>)>();
    final ptr = json.toNativeUtf8();
    try {
      return f(w, ptr);
    } finally {
      calloc.free(ptr);
    }
  }

  static int _step(Pointer<Void> w, double dt) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Uint8 Function(Pointer<Void>, Float)>>(
          'physics3d_world_step',
        )
        .asFunction<int Function(Pointer<Void>, double)>();
    return f(w, dt);
  }

  static int _bodyCount(Pointer<Void> w) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Uint32 Function(Pointer<Void>)>>(
          'physics3d_world_body_count',
        )
        .asFunction<int Function(Pointer<Void>)>();
    return f(w);
  }

  static List<double>? _bodyPosition(Pointer<Void> w, int index) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Uint8 Function(Pointer<Void>, Uint32, Pointer<Float>)>>(
          'physics3d_world_body_position',
        )
        .asFunction<int Function(Pointer<Void>, int, Pointer<Float>)>();
    final out = calloc<Float>(3);
    try {
      if (f(w, index, out) == 0) return null;
      return [out[0], out[1], out[2]];
    } finally {
      calloc.free(out);
    }
  }

  static String? _bodyId(Pointer<Void> w, int index) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Void>, Uint32)>>(
          'physics3d_world_body_id',
        )
        .asFunction<Pointer<Utf8> Function(Pointer<Void>, int)>();
    final ptr = f(w, index);
    if (ptr == nullptr) return null;
    try {
      return ptr.toDartString();
    } finally {
      EngineBridge.coreFreeString(ptr);
    }
  }
}
