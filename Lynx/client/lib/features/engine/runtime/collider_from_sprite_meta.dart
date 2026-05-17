import 'dart:math' as math;

import '../models/engine_models.dart';

class ColliderWorldAabb {
  final double centerX;
  final double centerY;
  final double width;
  final double height;

  const ColliderWorldAabb({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });

  factory ColliderWorldAabb.fromObjectBounds(SceneObject o) {
    final w = o.width * o.scaleX;
    final h = o.height * o.scaleY;
    return ColliderWorldAabb(centerX: o.x, centerY: o.y, width: w, height: h);
  }
}

ColliderWorldAabb computeColliderWorldAabb(SceneObject o, SpriteAssetMeta? meta) {
  final sw = o.width * o.scaleX;
  final sh = o.height * o.scaleY;
  if (meta == null || meta.colliderKind == SpriteColliderKind.none) {
    return ColliderWorldAabb(centerX: o.x, centerY: o.y, width: sw, height: sh);
  }

  final pivotPxX = o.width * o.originX;
  final pivotPxY = o.height * o.originY;

  if (meta.colliderKind == SpriteColliderKind.circle) {
    final rPx = meta.colliderRadius > 0
        ? meta.colliderRadius
        : math.min(o.width, o.height) / 2.0;
    final scaleAvg = (o.scaleX + o.scaleY) / 2.0;
    final d = rPx * 2 * scaleAvg;
    final lcX = meta.colliderOffsetX;
    final lcY = meta.colliderOffsetY;
    final dx = (lcX - pivotPxX) * o.scaleX;
    final dy = (lcY - pivotPxY) * o.scaleY;
    return ColliderWorldAabb(centerX: o.x + dx, centerY: o.y + dy, width: d, height: d);
  }

  final cwPx = meta.colliderWidth > 0 ? meta.colliderWidth : o.width;
  final chPx = meta.colliderHeight > 0 ? meta.colliderHeight : o.height;
  final w = cwPx * o.scaleX.abs();
  final h = chPx * o.scaleY.abs();
  final lcX = meta.colliderOffsetX + cwPx / 2.0;
  final lcY = meta.colliderOffsetY + chPx / 2.0;
  final dx = (lcX - pivotPxX) * o.scaleX;
  final dy = (lcY - pivotPxY) * o.scaleY;
  return ColliderWorldAabb(centerX: o.x + dx, centerY: o.y + dy, width: w, height: h);
}
