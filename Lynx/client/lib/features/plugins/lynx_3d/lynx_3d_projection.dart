import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Орбитальная камера + перспективная проекция для viewport / Play 3D.
class Lynx3dOrbitCamera {
  double yaw = 0.6;
  double pitch = 0.35;
  double distance = 12;

  void rotateBy(double dx, double dy) {
    yaw += dx * 0.01;
    pitch = (pitch + dy * 0.01).clamp(-1.2, 1.2);
  }

  void zoomBy(double delta) {
    distance = (distance + delta).clamp(4, 80);
  }

  Offset project(
    List<double> world, {
    required Size size,
    required List<double> lookAt,
    double fovYDeg = 60,
  }) {
    final lx = world[0] - lookAt[0];
    final ly = world[1] - lookAt[1];
    final lz = world[2] - lookAt[2];

    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    final x1 = lx * cy - lz * sy;
    final z1 = lx * sy + lz * cy;
    final y2 = ly * cp + z1 * sp;
    final z2 = -ly * sp + z1 * cp;

    final fov = fovYDeg * math.pi / 180;
    final aspect = size.width / size.height.clamp(1, 9999);
    final f = 1 / math.tan(fov * 0.5);
    final zCam = z2 + distance;
    if (zCam < 0.05) {
      return Offset(size.width * 0.5, size.height * 0.5);
    }
    final ndcX = (x1 * f / aspect) / zCam;
    final ndcY = (y2 * f) / zCam;
    return Offset(
      size.width * (0.5 + ndcX * 0.45),
      size.height * (0.5 - ndcY * 0.45),
    );
  }

  /// Глубина в пространстве камеры (для painter's algorithm).
  double viewDepth(List<double> world, List<double> lookAt) {
    final lx = world[0] - lookAt[0];
    final ly = world[1] - lookAt[1];
    final lz = world[2] - lookAt[2];
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);
    final z1 = lx * sy + lz * cy;
    return -ly * sp + z1 * cp + distance;
  }
}
