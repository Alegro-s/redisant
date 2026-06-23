import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/runtime/engine_color_codec.dart';
import '../engine/runtime/entity_render_sort.dart';
import '../engine/widgets/room_zones_paint.dart';
import 'game_render_snapshot.dart';
import 'sprite_uv_resolve.dart';
import 'tilemap_layer_painter.dart';

class GameWorldPainter extends CustomPainter {
  GameWorldPainter({
    required this.entities,
    required this.tilemaps,
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.designWidth,
    required this.designHeight,
    required this.elapsedSeconds,
    required this.textureImages,
    this.tilesetCatalog = const [],
    this.rooms = const [],
    this.logicGrids = const {},
    this.debugDrawRoomZones = false,
    this.debugDrawColliders = false,
  });

  factory GameWorldPainter.fromSnapshot({
    required GameRenderSnapshot snapshot,
    required double paintZoom,
    required double elapsedSeconds,
    required Map<String, ui.Image> textureImages,
    List<Map<String, dynamic>> tilesetCatalog = const [],
    bool debugDrawRoomZones = false,
    bool debugDrawColliders = false,
  }) {
    return GameWorldPainter(
      entities: snapshot.entities,
      tilemaps: snapshot.tilemaps,
      cameraX: snapshot.cameraX,
      cameraY: snapshot.cameraY,
      zoom: paintZoom,
      designWidth: snapshot.designWidth,
      designHeight: snapshot.designHeight,
      elapsedSeconds: elapsedSeconds,
      textureImages: textureImages,
      tilesetCatalog: tilesetCatalog,
      rooms: snapshot.rooms,
      logicGrids: snapshot.logicGrids,
      debugDrawRoomZones: debugDrawRoomZones,
      debugDrawColliders: debugDrawColliders,
    );
  }

  final List<Map<String, dynamic>> entities;
  final List<Map<String, dynamic>> tilemaps;
  final List<Map<String, dynamic>> tilesetCatalog;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double designWidth;
  final double designHeight;
  final double elapsedSeconds;
  final Map<String, ui.Image> textureImages;
  final List<Map<String, dynamic>> rooms;
  final Map<String, Map<String, dynamic>> logicGrids;
  final bool debugDrawRoomZones;
  final bool debugDrawColliders;

  void _drawText(Canvas canvas, String text, Offset at, {double size = 14, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  void _paintTetrisBoardFrame(Canvas canvas, Size size) {
    if (!logicGrids.containsKey('display')) return;
    const cell = 24.0;
    final grid = logicGrids['display']!;
    final w = (grid['w'] as num?)?.toInt() ?? 10;
    final h = (grid['h'] as num?)?.toInt() ?? 20;
    final ox = (designWidth - w * cell) / 2;
    final oy = (designHeight - h * cell) / 2;
    const pad = 6.0;
    final tl = _worldToScreen(ox - pad, oy - pad, size);
    final br = _worldToScreen(ox + w * cell + pad, oy + h * cell + pad, size);
    final outer = Rect.fromPoints(tl, br);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(4)),
      Paint()..color = const Color(0xFF1A1F2E),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, const Radius.circular(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6B7280),
    );
    final inner = Rect.fromPoints(
      _worldToScreen(ox, oy, size),
      _worldToScreen(ox + w * cell, oy + h * cell, size),
    );
    canvas.drawRect(inner, Paint()..color = const Color(0xFF0A0E14));
  }

  void _paintTetrisHud(Canvas canvas, Size size) {
    if (designWidth > 520 || designHeight < 600) return;
    final vars = logicGrids['vars'];
    if (vars == null) return;
    final cells = vars['cells'];
    if (cells is! List || cells.isEmpty) return;
    final phase = (cells[0] as num?)?.toInt() ?? 0;
    final score = cells.length > 6 ? (cells[6] as num?)?.toInt() ?? 0 : 0;
    final lines = cells.length > 7 ? (cells[7] as num?)?.toInt() ?? 0 : 0;

    _drawText(canvas, 'SCORE $score', Offset(12, 12), size: 13, color: Colors.white70);
    _drawText(canvas, 'LINES $lines', Offset(12, 30), size: 12, color: Colors.white54);

    if (phase == 0) {
      _drawText(
        canvas,
        'TETRIS',
        Offset(size.width / 2 - 48, size.height / 2 - 40),
        size: 28,
      );
      _drawText(
        canvas,
        'Tap / Enter — начать',
        Offset(size.width / 2 - 76, size.height / 2 + 4),
        size: 13,
        color: Colors.white70,
      );
    } else if (phase == 2) {
      _drawText(
        canvas,
        'GAME OVER',
        Offset(size.width / 2 - 56, size.height / 2 - 24),
        size: 22,
        color: const Color(0xFFFF5252),
      );
      _drawText(
        canvas,
        'Enter — меню',
        Offset(size.width / 2 - 44, size.height / 2 + 8),
        size: 13,
        color: Colors.white70,
      );
    }
  }

  Offset _worldToScreen(double wx, double wy, Size viewSize) {
    final sx = viewSize.width / 2 + (wx - cameraX) * zoom;
    final sy = viewSize.height / 2 + (wy - cameraY) * zoom;
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0d1117),
    );

    paintRustFormatTilemaps(
      canvas: canvas,
      viewSize: size,
      tilemaps: tilemaps,
      tilesetCatalog: tilesetCatalog,
      textureImages: textureImages,
      worldToScreen: (wx, wy) => _worldToScreen(wx, wy, size),
      zoom: zoom,
    );

    if (debugDrawRoomZones && rooms.isNotEmpty) {
      paintRustRoomZonesWorld(
        canvas: canvas,
        rooms: rooms,
        worldToScreen: (wx, wy) => _worldToScreen(wx, wy, size),
      );
    }

    _paintTetrisBoardFrame(canvas, size);
    _paintLogicGrids(canvas, size);

    for (final entity in sortedEntitiesForRender(entities)) {
      if (entity['visible'] == false) continue;
      final transform = entity['transform'] as Map<String, dynamic>?;
      if (transform == null) continue;
      final pos = transform['pos'] as Map<String, dynamic>;
      final sizeMap = transform['size'] as Map<String, dynamic>;
      final px = (pos['x'] as num).toDouble();
      final py = (pos['y'] as num).toDouble();
      final sx0 = (sizeMap['x'] as num).toDouble();
      final sy0 = (sizeMap['y'] as num).toDouble();

      final sp = entity['sprite'] as Map<String, dynamic>?;
      final vo = sp?['visual_offset'] as Map<String, dynamic>?;
      final vox = (vo?['x'] as num?)?.toDouble() ?? 0;
      final voy = (vo?['y'] as num?)?.toDouble() ?? 0;
      final drawW = (sp?['visual_width'] as num?)?.toDouble() ?? sx0;
      final drawH = (sp?['visual_height'] as num?)?.toDouble() ?? sy0;
      final cx = px + vox;
      final cy = py + voy;

      final texPath = sp?['texture_path'] as String?;
      final img = texPath != null ? textureImages[texPath] : null;

      final uv = resolveSpriteUvRect(
        engineUv: sp?['uv_rect'] as Map<String, dynamic>?,
        sprite: sp,
        elapsedSeconds: elapsedSeconds,
      );

      final center = _worldToScreen(cx, cy, size);
      final dst = Rect.fromCenter(
        center: center,
        width: drawW * zoom,
        height: drawH * zoom,
      );

      if (img != null && uv != null) {
        final uw = (uv['w'] as num).toDouble();
        final uh = (uv['h'] as num).toDouble();
        if (uw > 0 && uh > 0) {
          final src = Rect.fromLTWH(
            (uv['x'] as num).toDouble(),
            (uv['y'] as num).toDouble(),
            uw,
            uh,
          );
          canvas.save();
          final rot = ((transform['rot'] as num?)?.toDouble() ?? 0) * 3.1415926535 / 180;
          if (rot != 0) {
            canvas.translate(center.dx, center.dy);
            canvas.rotate(rot);
            canvas.translate(-center.dx, -center.dy);
          }
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.medium,
          );
          canvas.restore();
          continue;
        }
      }

      final colorHex = (sp?['color_hex'] as int?) ?? 0xff808080;
      final color = engineArgbToFlutterColor(colorHex);
      canvas.drawRect(dst, Paint()..color = color);

      if (debugDrawColliders) {
        final colCenter = _worldToScreen(px, py, size);
        final colRect = Rect.fromCenter(
          center: colCenter,
          width: sx0 * zoom,
          height: sy0 * zoom,
        );
        canvas.drawRect(
          colRect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.cyanAccent.withValues(alpha: 0.7),
        );
      }
    }

    _paintTetrisHud(canvas, size);
  }

  static const List<Color> _logicGridPalette = [
    Color(0x00000000),
    Color(0xFF00F0F0),
    Color(0xFFF0F000),
    Color(0xFFA000F0),
    Color(0xFF00F000),
    Color(0xFFF00000),
    Color(0xFF0000F0),
    Color(0xFFF0A000),
  ];

  void _paintLogicGrids(Canvas canvas, Size size) {
    if (logicGrids.isEmpty) return;
    const cell = 24.0;
    final gridsToPaint = logicGrids.containsKey('display')
        ? {'display': logicGrids['display']!}
        : Map<String, Map<String, dynamic>>.fromEntries(
            logicGrids.entries.where((e) => e.key != 'vars' && e.key != 'board'),
          );
    for (final entry in gridsToPaint.entries) {
      final grid = entry.value;
      final w = (grid['w'] as num?)?.toInt() ?? 0;
      final h = (grid['h'] as num?)?.toInt() ?? 0;
      if (w <= 0 || h <= 0) continue;
      final cellsRaw = grid['cells'];
      if (cellsRaw is! List) continue;
      final ox = (designWidth - w * cell) / 2;
      final oy = (designHeight - h * cell) / 2;

      final gridLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..color = const Color(0xFF3D4A5C);
      final cellA = const Color(0xFF10151C);
      final cellB = const Color(0xFF141A22);

      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final topLeft = _worldToScreen(ox + x * cell, oy + y * cell, size);
          final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, cell * zoom, cell * zoom);
          canvas.drawRect(
            rect,
            Paint()..color = ((x + y) & 1) == 0 ? cellA : cellB,
          );
          canvas.drawRect(rect, gridLine);
        }
      }

      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final idx = y * w + x;
          if (idx >= cellsRaw.length) continue;
          final v = (cellsRaw[idx] as num?)?.toInt() ?? 0;
          if (v <= 0) continue;
          final topLeft = _worldToScreen(ox + x * cell, oy + y * cell, size);
          final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, cell * zoom, cell * zoom);
          final inset = (cell * zoom * 0.08).clamp(1.0, 3.0);
          final block = rect.deflate(inset);
          if (v >= 100) {
            final base = v - 100;
            if (base <= 0 || base >= _logicGridPalette.length) continue;
            canvas.drawRect(
              block,
              Paint()..color = _logicGridPalette[base].withValues(alpha: 0.28),
            );
            continue;
          }
          if (v >= _logicGridPalette.length) continue;
          canvas.drawRect(block, Paint()..color = _logicGridPalette[v]);
          canvas.drawRect(
            block,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.white24,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GameWorldPainter oldDelegate) {
    return oldDelegate.entities != entities ||
        oldDelegate.tilemaps != tilemaps ||
        oldDelegate.cameraX != cameraX ||
        oldDelegate.cameraY != cameraY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.designWidth != designWidth ||
        oldDelegate.designHeight != designHeight ||
        oldDelegate.elapsedSeconds != elapsedSeconds ||
        oldDelegate.textureImages != textureImages ||
        oldDelegate.tilesetCatalog != tilesetCatalog ||
        oldDelegate.rooms != rooms ||
        oldDelegate.logicGrids != logicGrids ||
        oldDelegate.debugDrawRoomZones != debugDrawRoomZones ||
        oldDelegate.debugDrawColliders != debugDrawColliders;
  }
}
