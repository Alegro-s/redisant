import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'lynx_3d_projection.dart';
import 'lynx_glb_mesh.dart';

/// Отрисовка GLB-мешей с z-sort и простым освещением.
class Lynx3dMeshRenderer {
  static const _lightDir = [0.35, 0.85, 0.4];

  static void drawObjectMesh({
    required Canvas canvas,
    required Size size,
    required Lynx3dOrbitCamera camera,
    required List<double> lookAt,
    required LynxGlbMesh mesh,
    required List<double> position,
    required List<double> rotationEuler,
    required List<double> scale,
    required Color baseColor,
    double fovYDeg = 60,
  }) {
    final tris = _buildTriangles(
      mesh: mesh,
      position: position,
      rotationEuler: rotationEuler,
      scale: scale,
      baseColor: baseColor,
      camera: camera,
      size: size,
      lookAt: lookAt,
      fovYDeg: fovYDeg,
    );
    tris.sort((a, b) => b.depth.compareTo(a.depth));
    for (final t in tris) {
      final path = Path()
        ..moveTo(t.p0.dx, t.p0.dy)
        ..lineTo(t.p1.dx, t.p1.dy)
        ..lineTo(t.p2.dx, t.p2.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = t.color);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
  }

  static List<_Tri> _buildTriangles({
    required LynxGlbMesh mesh,
    required List<double> position,
    required List<double> rotationEuler,
    required List<double> scale,
    required Color baseColor,
    required Lynx3dOrbitCamera camera,
    required Size size,
    required List<double> lookAt,
    required double fovYDeg,
  }) {
    final tris = <_Tri>[];
    final pos = mesh.positions;
    final norm = mesh.normals;
    final idx = mesh.indices;

    for (var t = 0; t < idx.length; t += 3) {
      final i0 = idx[t] * 3, i1 = idx[t + 1] * 3, i2 = idx[t + 2] * 3;
      final w0 = _transformVertex(
        pos[i0], pos[i0 + 1], pos[i0 + 2],
        position, rotationEuler, scale,
      );
      final w1 = _transformVertex(
        pos[i1], pos[i1 + 1], pos[i1 + 2],
        position, rotationEuler, scale,
      );
      final w2 = _transformVertex(
        pos[i2], pos[i2 + 1], pos[i2 + 2],
        position, rotationEuler, scale,
      );
      final n = _avgNormal(
        _transformNormal(norm[i0], norm[i0 + 1], norm[i0 + 2], rotationEuler),
        _transformNormal(norm[i1], norm[i1 + 1], norm[i1 + 2], rotationEuler),
        _transformNormal(norm[i2], norm[i2 + 1], norm[i2 + 2], rotationEuler),
      );
      final shade = (_dot(n, _lightDir) * 0.65 + 0.35).clamp(0.2, 1.0);
      final col = Color.lerp(
        baseColor.withValues(alpha: 1),
        Colors.black,
        1 - shade,
      )!;
      final p0 = camera.project(w0, size: size, lookAt: lookAt, fovYDeg: fovYDeg);
      final p1 = camera.project(w1, size: size, lookAt: lookAt, fovYDeg: fovYDeg);
      final p2 = camera.project(w2, size: size, lookAt: lookAt, fovYDeg: fovYDeg);
      final depth = (camera.viewDepth(w0, lookAt) +
              camera.viewDepth(w1, lookAt) +
              camera.viewDepth(w2, lookAt)) /
          3;
      if (_backFacing(p0, p1, p2)) continue;
      tris.add(_Tri(p0, p1, p2, col, depth));
    }
    return tris;
  }

  static bool _backFacing(Offset a, Offset b, Offset c) {
    return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx) <= 0;
  }

  static double _dot(List<double> a, List<double> b) =>
      a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

  static List<double> _avgNormal(List<double> a, List<double> b, List<double> c) {
    final nx = a[0] + b[0] + c[0];
    final ny = a[1] + b[1] + c[1];
    final nz = a[2] + b[2] + c[2];
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-6) return [0, 1, 0];
    return [nx / len, ny / len, nz / len];
  }

  static List<double> _transformVertex(
    double x,
    double y,
    double z,
    List<double> pos,
    List<double> rotDeg,
    List<double> scale,
  ) {
    x *= scale[0];
    y *= scale[1];
    z *= scale[2];
    final rx = rotDeg[0] * math.pi / 180;
    final ry = rotDeg[1] * math.pi / 180;
    final rz = rotDeg[2] * math.pi / 180;
    var cy = math.cos(ry), sy = math.sin(ry);
    var cx = math.cos(rx), sx = math.sin(rx);
    var cz = math.cos(rz), sz = math.sin(rz);
    var x1 = x * cy + z * sy;
    var z1 = -x * sy + z * cy;
    var y1 = y;
    final y2 = y1 * cx - z1 * sx;
    final z2 = y1 * sx + z1 * cx;
    final x2 = x1;
    final x3 = x2 * cz - y2 * sz;
    final y3 = x2 * sz + y2 * cz;
    return [x3 + pos[0], y3 + pos[1], z2 + pos[2]];
  }

  static List<double> _transformNormal(
    double x,
    double y,
    double z,
    List<double> rotDeg,
  ) {
    return _transformVertex(x, y, z, [0, 0, 0], rotDeg, [1, 1, 1]);
  }
}

class _Tri {
  _Tri(this.p0, this.p1, this.p2, this.color, this.depth);
  final Offset p0, p1, p2;
  final Color color;
  final double depth;
}
