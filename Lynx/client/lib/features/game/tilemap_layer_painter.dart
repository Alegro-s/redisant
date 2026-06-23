import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'tilemap_catalog.dart';

void paintRustFormatTilemaps({
  required Canvas canvas,
  required Size viewSize,
  required List<Map<String, dynamic>> tilemaps,
  required List<Map<String, dynamic>> tilesetCatalog,
  required Map<String, ui.Image> textureImages,
  required Offset Function(double wx, double wy) worldToScreen,
  required double zoom,
  double collisionFallbackAlpha = 0.92,
  bool collisionTintInEditor = false,
}) {
  if (tilemaps.isEmpty) return;

  Color tileCollisionColor(int coll) {
    switch (coll) {
      case 1:
        return const Color(0xFF3d444d);
      case 2:
        return const Color(0xFF2a6b7a);
      case 3:
        return const Color(0xFF7a5a2a);
      case 4:
        return const Color(0xFF6a2a7a);
      default:
        return const Color(0xFF252a33);
    }
  }

  Color decorativeTileColor(int tileId) {
    final hue = (tileId * 47) % 360;
    return HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.42).toColor();
  }

  final sorted = List<Map<String, dynamic>>.from(tilemaps);
  sorted.sort((a, b) {
    final za = (a['z_order'] as num?)?.toInt() ?? 0;
    final zb = (b['z_order'] as num?)?.toInt() ?? 0;
    return za.compareTo(zb);
  });

  for (final layer in sorted) {
    if (layer['visible'] == false) continue;
    final dstTw = (layer['tile_w'] as num?)?.toDouble() ?? 32;
    final dstTh = (layer['tile_h'] as num?)?.toDouble() ?? 32;
    final autotile = layer['autotile'] == true;
    final tilesetId = layer['tileset_id'] as String?;
    final cat = TilesetCatalogEntry.find(tilesetCatalog, tilesetId);
    final texturePath = cat?.texturePath ?? '';
    final columns = cat?.columns ?? 16;
    final srcTw = cat?.sourceTileW ?? dstTw;
    final srcTh = cat?.sourceTileH ?? dstTh;
    final img = texturePath.isNotEmpty ? textureImages[texturePath] : null;

    final chunks = layer['chunks'] as List? ?? [];
    for (final raw in chunks) {
      final ch = Map<String, dynamic>.from(raw as Map);
      final cx = (ch['cx'] as num?)?.toInt() ?? 0;
      final cy = (ch['cy'] as num?)?.toInt() ?? 0;
      final ctw = (ch['tw'] as num?)?.toInt() ?? 0;
      final cth = (ch['th'] as num?)?.toInt() ?? 0;
      final collList = (ch['collision'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const <int>[];
      final tileList = (ch['tile_ids'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const <int>[];

      final baseX = cx * ctw * dstTw;
      final baseY = cy * cth * dstTh;

      for (var ly = 0; ly < cth; ly++) {
        for (var lx = 0; lx < ctw; lx++) {
          final i = ly * ctw + lx;
          final coll = i < collList.length ? collList[i] : 0;
          final tileId = i < tileList.length ? tileList[i] : 0;
          if (tileId == 0 && coll == 0) continue;

          final wx = baseX + lx * dstTw + dstTw / 2;
          final wy = baseY + ly * dstTh + dstTh / 2;
          final center = worldToScreen(wx, wy);
          final dst = Rect.fromCenter(
            center: center,
            width: dstTw * zoom,
            height: dstTh * zoom,
          );

          var drewAtlas = false;
          if (img != null && columns > 0 && srcTw > 0 && srcTh > 0) {
            int? atlasIndex;
            if (autotile) {
              if (tileId >= 0) atlasIndex = tileId;
            } else if (tileId >= 1) {
              atlasIndex = tileId - 1;
            }
            if (atlasIndex != null && atlasIndex >= 0) {
              final col = atlasIndex % columns;
              final row = atlasIndex ~/ columns;
              final srcLeft = col * srcTw;
              final srcTop = row * srcTh;
              if (srcLeft + srcTw <= img.width + 0.5 &&
                  srcTop + srcTh <= img.height + 0.5) {
                final src = Rect.fromLTWH(srcLeft, srcTop, srcTw, srcTh);
                canvas.drawImageRect(
                  img,
                  src,
                  dst,
                  Paint()..filterQuality = FilterQuality.medium,
                );
                drewAtlas = true;
              }
            }
          }

          if (!drewAtlas && tileId > 0 && !collisionTintInEditor) {
            canvas.drawRect(
              dst,
              Paint()..color = decorativeTileColor(tileId).withValues(alpha: 0.88),
            );
            drewAtlas = true;
          }

          if (!drewAtlas && coll != 0) {
            final a = collisionTintInEditor ? 0.55 : collisionFallbackAlpha;
            canvas.drawRect(dst, Paint()..color = tileCollisionColor(coll).withValues(alpha: a));
            canvas.drawRect(
              dst,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = collisionTintInEditor ? 0.5 : 1
                ..color = const Color(0x22FFFFFF),
            );
          }
        }
      }
    }
  }
}
