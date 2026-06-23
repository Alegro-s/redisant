import 'package:flutter/services.dart';

import 'package:client/features/engine/ffi/engine_bridge.dart';
import 'package:client/features/engine/ffi/engine_types.dart';
import 'package:client/features/engine/runtime/nexus_gamepad_feeder.dart';
import 'game_render_snapshot.dart';

/// Tetris / logic-grid игры (Lua + `display` grid).
bool snapshotIsLogicGridGame(GameRenderSnapshot snapshot) {
  return snapshot.logicGrids.containsKey('display');
}

bool sceneDataIsLogicGridGame(Map<String, dynamic> sceneData) {
  final raw = sceneData['logic_grids'];
  return raw is Map && raw.containsKey('display');
}

void lockCameraForLogicGrid({
  required double designWidth,
  required double designHeight,
  required void Function(double x, double y) setCenter,
  required void Function(double zoom) setZoom,
}) {
  setCenter(designWidth / 2, designHeight / 2);
  setZoom(1);
}

int logicGridPhase(GameRenderSnapshot snapshot) {
  final vars = snapshot.logicGrids['vars'];
  if (vars == null) return -1;
  final cells = vars['cells'];
  if (cells is! List || cells.isEmpty) return -1;
  return (cells[0] as num?)?.toInt() ?? -1;
}

void dispatchPlayEngineKey(SceneHandle scene, LogicalKeyboardKey key, bool down) {
  if (sceneIsNull(scene)) return;
  if (key == LogicalKeyboardKey.space) {
    EngineBridge.sceneSetKey(scene, ' ', down);
    return;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    EngineBridge.sceneSetNamedKey(scene, 'Left', down);
    return;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    EngineBridge.sceneSetNamedKey(scene, 'Right', down);
    return;
  }
  if (key == LogicalKeyboardKey.arrowUp) {
    EngineBridge.sceneSetNamedKey(scene, 'Up', down);
    return;
  }
  if (key == LogicalKeyboardKey.arrowDown) {
    EngineBridge.sceneSetNamedKey(scene, 'Down', down);
    return;
  }
  if (key == LogicalKeyboardKey.enter) {
    EngineBridge.sceneSetNamedKey(scene, 'Return', down);
    return;
  }
  final ch = key.keyLabel;
  if (ch.length == 1) {
    EngineBridge.sceneSetKey(scene, ch.toLowerCase(), down);
  }
}

void pulsePlayEngineKey(SceneHandle scene, LogicalKeyboardKey key) {
  dispatchPlayEngineKey(scene, key, true);
  dispatchPlayEngineKey(scene, key, false);
}

const int kPlayGpA = 1;
const int kPlayGpB = 2;
const int kPlayGpDLeft = 4;
const int kPlayGpDRight = 8;
const int kPlayGpDUp = 16;
const int kPlayGpDDown = 32;

void setPlayGamepadButtons(SceneHandle scene, int mask) {
  NexusGamepadFeeder.setClientButtonMask(mask);
  if (!sceneIsNull(scene)) {
    NexusGamepadFeeder.syncToScene(scene);
  }
}

int playGamepadBitForArrow(LogicalKeyboardKey key) {
  return switch (key) {
    LogicalKeyboardKey.arrowLeft => kPlayGpDLeft,
    LogicalKeyboardKey.arrowRight => kPlayGpDRight,
    LogicalKeyboardKey.arrowUp => kPlayGpDUp,
    LogicalKeyboardKey.arrowDown => kPlayGpDDown,
    _ => 0,
  };
}
