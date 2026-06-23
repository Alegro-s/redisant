import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ffi/engine_bridge.dart';
import '../ffi/engine_types.dart';

/// Синхронизация виртуального геймпада (тач-кнопки Play) с движком.
class NexusGamepadFeeder {
  NexusGamepadFeeder._();

  static StreamSubscription<void>? _sub;
  static int _clientButtonMask = 0;

  static void attachForPlay() {
    if (kIsWeb) return;
    _sub ??= const Stream<void>.empty().listen((_) {});
  }

  static void disposeForPlay() {
    _sub?.cancel();
    _sub = null;
    _clientButtonMask = 0;
  }

  /// Тач-HUD выставляет биты: 1=A, 2=B, 4=←, 8=→, 16=↑, 32=↓.
  static void setClientButtonMask(int mask) {
    _clientButtonMask = mask & 0x3F;
  }

  static void syncToScene(SceneHandle scene) {
    if (kIsWeb || sceneIsNull(scene)) return;
    EngineBridge.sceneSetGamepad(scene, 0.0, 0.0, _clientButtonMask);
  }
}
