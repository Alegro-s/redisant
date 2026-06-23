import 'package:flutter/material.dart';

import 'lynx_3d_codec.dart';
import 'lynx_3d_mesh_renderer.dart';
import 'lynx_3d_projection.dart';
import 'lynx_glb_mesh.dart';

class Lynx3dViewportPainter extends CustomPainter {
  Lynx3dViewportPainter({
    required this.extension,
    required this.camera,
    this.meshesByPath = const {},
    this.showGrid = true,
  });

  final Lynx3dSceneExtension extension;
  final Lynx3dOrbitCamera camera;
  final Map<String, LynxGlbMesh> meshesByPath;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final lookAt = extension.room?.center ?? [0, 2, 0];
    final bg = _parseAmbient(extension.ambientColor);
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    if (showGrid) _drawGrid(canvas, size, lookAt);

    final room = extension.room;
    if (room != null) {
      _drawRoom(canvas, size, room, lookAt);
    }

    final fov = extension.camera.fovY;
    for (final obj in extension.objects) {
      final color = Color(obj.colorArgb);
      final meshPath = obj.mesh;
      final mesh = meshPath != null && meshPath.isNotEmpty
          ? meshesByPath[meshPath]
          : null;
      if (mesh != null) {
        Lynx3dMeshRenderer.drawObjectMesh(
          canvas: canvas,
          size: size,
          camera: camera,
          lookAt: lookAt,
          mesh: mesh,
          position: obj.position,
          rotationEuler: obj.rotationEuler,
          scale: obj.scale,
          baseColor: color,
          fovYDeg: fov,
        );
      } else {
        _drawBox(
          canvas,
          size,
          lookAt,
          obj.position,
          obj.halfExtents,
          color,
          label: obj.id,
          fovYDeg: fov,
        );
      }
    }

    _drawAxes(canvas, size, lookAt);
  }

  void _drawGrid(Canvas canvas, Size size, List<double> lookAt) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = -4; i <= 4; i++) {
      final a = camera.project([i.toDouble(), 0, -4], size: size, lookAt: lookAt);
      final b = camera.project([i.toDouble(), 0, 4], size: size, lookAt: lookAt);
      canvas.drawLine(a, b, paint);
      final c = camera.project([-4, 0, i.toDouble()], size: size, lookAt: lookAt);
      final d = camera.project([4, 0, i.toDouble()], size: size, lookAt: lookAt);
      canvas.drawLine(c, d, paint);
    }
  }

  void _drawRoom(Canvas canvas, Size size, Lynx3dRoom room, List<double> lookAt) {
    final cx = room.center[0];
    final cy = room.center[1];
    final cz = room.center[2];
    final hw = room.width * 0.5;
    final hh = room.height * 0.5;
    final hd = room.depth * 0.5;
    final wire = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final corners = [
      [cx - hw, cy - hh, cz - hd],
      [cx + hw, cy - hh, cz - hd],
      [cx + hw, cy - hh, cz + hd],
      [cx - hw, cy - hh, cz + hd],
      [cx - hw, cy + hh, cz - hd],
      [cx + hw, cy + hh, cz - hd],
      [cx + hw, cy + hh, cz + hd],
      [cx - hw, cy + hh, cz + hd],
    ];
    final scr = corners
        .map((c) => camera.project(c, size: size, lookAt: lookAt))
        .toList();
    const edges = [
      [0, 1],
      [1, 2],
      [2, 3],
      [3, 0],
      [4, 5],
      [5, 6],
      [6, 7],
      [7, 4],
      [0, 4],
      [1, 5],
      [2, 6],
      [3, 7],
    ];
    for (final e in edges) {
      canvas.drawLine(scr[e[0]], scr[e[1]], wire);
    }
    final floor = Paint()..color = Colors.white.withValues(alpha: 0.04);
    final f0 = camera.project([cx - hw, cy - hh, cz - hd], size: size, lookAt: lookAt);
    final f1 = camera.project([cx + hw, cy - hh, cz - hd], size: size, lookAt: lookAt);
    final f2 = camera.project([cx + hw, cy - hh, cz + hd], size: size, lookAt: lookAt);
    final f3 = camera.project([cx - hw, cy - hh, cz + hd], size: size, lookAt: lookAt);
    final path = Path()
      ..moveTo(f0.dx, f0.dy)
      ..lineTo(f1.dx, f1.dy)
      ..lineTo(f2.dx, f2.dy)
      ..lineTo(f3.dx, f3.dy)
      ..close();
    canvas.drawPath(path, floor);
  }

  void _drawBox(
    Canvas canvas,
    Size size,
    List<double> lookAt,
    List<double> pos,
    List<double> half,
    Color color, {
    String? label,
    double fovYDeg = 60,
  }) {
    final cx = pos[0];
    final cy = pos[1];
    final cz = pos[2];
    final hx = half[0];
    final hy = half[1];
    final hz = half[2];
    final corners = [
      [cx - hx, cy - hy, cz - hz],
      [cx + hx, cy - hy, cz - hz],
      [cx + hx, cy - hy, cz + hz],
      [cx - hx, cy - hy, cz + hz],
      [cx - hx, cy + hy, cz - hz],
      [cx + hx, cy + hy, cz - hz],
      [cx + hx, cy + hy, cz + hz],
      [cx - hx, cy + hy, cz + hz],
    ];
    final scr = corners
        .map((c) => camera.project(c, size: size, lookAt: lookAt, fovYDeg: fovYDeg))
        .toList();
    final faces = [
      [0, 1, 2, 3],
      [4, 5, 6, 7],
      [0, 1, 5, 4],
      [1, 2, 6, 5],
      [2, 3, 7, 6],
      [3, 0, 4, 7],
    ];
    for (final f in faces) {
      final path = Path()
        ..moveTo(scr[f[0]].dx, scr[f[0]].dy)
        ..lineTo(scr[f[1]].dx, scr[f[1]].dy)
        ..lineTo(scr[f[2]].dx, scr[f[2]].dy)
        ..lineTo(scr[f[3]].dx, scr[f[3]].dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: 0.55),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    if (label != null) {
      final tp = camera.project(
        [cx, cy + hy + 0.2, cz],
        size: size,
        lookAt: lookAt,
        fovYDeg: fovYDeg,
      );
      final tpainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpainter.paint(canvas, tp - Offset(tpainter.width * 0.5, 0));
    }
  }

  void _drawAxes(Canvas canvas, Size size, List<double> lookAt) {
    final o = camera.project(lookAt, size: size, lookAt: lookAt);
    void axis(List<double> end, Color c) {
      final p = camera.project(end, size: size, lookAt: lookAt);
      canvas.drawLine(o, p, Paint()..color = c..strokeWidth = 2);
    }

    axis([lookAt[0] + 1.5, lookAt[1], lookAt[2]], Colors.redAccent);
    axis([lookAt[0], lookAt[1] + 1.5, lookAt[2]], Colors.greenAccent);
    axis([lookAt[0], lookAt[1], lookAt[2] + 1.5], Colors.blueAccent);
  }

  Color _parseAmbient(String hex) {
    if (hex.startsWith('#') && hex.length >= 7) {
      final n = int.tryParse(hex.substring(1, 7), radix: 16);
      if (n != null) return Color(0xFF000000 | n);
    }
    return const Color(0xFF2A2D35);
  }

  @override
  bool shouldRepaint(covariant Lynx3dViewportPainter old) =>
      old.extension != extension ||
      old.meshesByPath != meshesByPath ||
      old.camera.yaw != camera.yaw ||
      old.camera.pitch != camera.pitch ||
      old.camera.distance != camera.distance;
}
