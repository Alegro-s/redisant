import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/runtime/engine_color_codec.dart';
import '../engine/runtime/entity_render_sort.dart';
import '../engine/widgets/room_zones_paint.dart';
import 'game_render_snapshot.dart';
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
  final bool debugDrawRoomZones;
  final bool debugDrawColliders;

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

      Map<String, dynamic>? uv = sp?['uv_rect'] as Map<String, dynamic>?;
      final anim = sp?['animation'] as Map<String, dynamic>?;
      final frames = anim?['frames'] as List<dynamic>?;
      final fps = (anim?['fps'] as num?)?.toDouble() ?? 8;
      if (frames != null && frames.isNotEmpty) {
        final fi = (elapsedSeconds * fps).floor() % frames.length;
        uv = Map<String, dynamic>.from(frames[fi] as Map);
      }

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
        oldDelegate.debugDrawRoomZones != debugDrawRoomZones ||
        oldDelegate.debugDrawColliders != debugDrawColliders;
  }
}
