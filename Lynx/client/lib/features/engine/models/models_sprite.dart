import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

enum SpriteType { Object, Player, Enemy, Item }

class PlacedSprite {
  final String id;
  final List<List<Color?>> pixels;
  final ui.Image? image;
  final double gridX;
  final double gridY;
  final int scale;
  final SpriteType type;
  final String? luaScript;
  final bool hasCollision;

  PlacedSprite({
    required this.id,
    required this.pixels,
    this.image,
    required this.gridX,
    required this.gridY,
    required this.scale,
    required this.type,
    this.luaScript,
    this.hasCollision = false,
  });

  PlacedSprite cloneAt(double x, double y) {
    return PlacedSprite(
      id: '${id}_copy',
      pixels: pixels.map((row) => [...row]).toList(),
      image: image,
      gridX: x,
      gridY: y,
      scale: scale,
      type: type,
      luaScript: luaScript,
      hasCollision: hasCollision,
    );
  }
}

class AssetItem {
  final String name;
  final ui.Image? image;
  final Uint8List? bytes;
  final String? luaCode;
  final int? originalWidth;
  final int? originalHeight;
  final String assetType; // 'sprite', 'script', 'sound'

  AssetItem({
    required this.name,
    this.image,
    this.bytes,
    this.luaCode,
    this.originalWidth,
    this.originalHeight,
    required this.assetType,
  });

  get pos => null;
}