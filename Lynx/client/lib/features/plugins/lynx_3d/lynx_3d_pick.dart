import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lynx_3d_codec.dart';
import 'lynx_3d_projection.dart';

/// Выбор 3D-объекта по клику в viewport.
String? pickLynx3dObjectAt({
  required Offset screen,
  required Size size,
  required Lynx3dSceneExtension extension,
  required Lynx3dOrbitCamera camera,
  double maxDistance = 28,
}) {
  final lookAt = extension.room?.center ?? [0, 2, 0];
  final fov = extension.camera.fovY;
  String? bestId;
  var bestDist = maxDistance;

  for (final obj in extension.objects) {
    final p = camera.project(
      obj.position,
      size: size,
      lookAt: lookAt,
      fovYDeg: fov,
    );
    final d = (p - screen).distance;
    if (d < bestDist) {
      bestDist = d;
      bestId = obj.id;
    }
  }
  return bestId;
}

/// Сдвиг объекта по плоскости XZ при drag.
List<double> dragLynx3dObjectOnPlane({
  required Offset screenDelta,
  required Size size,
  required List<double> position,
  required Lynx3dOrbitCamera camera,
  required List<double> lookAt,
  double fovYDeg = 60,
}) {
  final yaw = camera.yaw;
  final scale = 0.02 * (camera.distance / 12).clamp(0.35, 2.5);
  final dx = screenDelta.dx * scale;
  final dy = screenDelta.dy * scale;
  final cosY = math.cos(yaw);
  final sinY = math.sin(yaw);
  final wx = dx * cosY + dy * sinY;
  final wz = -dx * sinY + dy * cosY;
  return [
    position[0] + wx,
    position.length > 1 ? position[1] : 0,
    position.length > 2 ? position[2] + wz : wz,
  ];
}
