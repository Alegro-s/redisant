import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ffi/engine_bridge.dart';
import '../ffi/engine_types.dart';

class NexusGamepadFeeder {
  NexusGamepadFeeder._();

  static StreamSubscription<void>? _sub;

  static void attachForPlay() {
    if (kIsWeb) return;
    _sub ??= const Stream<void>.empty().listen((_) {});
  }

  static void disposeForPlay() {
    _sub?.cancel();
    _sub = null;
  }

  static void syncToScene(SceneHandle scene) {
    if (kIsWeb || sceneIsNull(scene)) return;
    EngineBridge.sceneSetGamepad(scene, 0.0, 0.0, 0);
  }
}
