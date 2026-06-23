import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';

/// Мини-карта сцены (Unity-style overview).
class SceneMinimapPanel extends StatelessWidget {
  const SceneMinimapPanel({
    super.key,
    this.onFocusScenePoint,
    this.viewportMatrix,
    this.viewportSize = Size.zero,
  });

  final void Function(Offset scenePoint)? onFocusScenePoint;
  final Matrix4? viewportMatrix;
  final Size viewportSize;

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SceneProvider>();
    final mgr = context.watch<ProjectManager>();
    final scene = sp.currentScene;
    final cs = Theme.of(context).colorScheme;

    if (scene == null) {
      return Center(
        child: Text('Нет сцены', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Карта',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: LayoutBuilder(
              builder: (context, c) {
                return GestureDetector(
                  onTapDown: (d) {
                    final pt = _sceneFromMinimap(
                      d.localPosition,
                      c.biggest,
                      scene,
                    );
                    onFocusScenePoint?.call(pt);
                  },
                  child: CustomPaint(
                    painter: _SceneMinimapPainter(
                      scene: scene,
                      assets: mgr.assets,
                      viewportMatrix: viewportMatrix,
                      viewportSize: viewportSize,
                      colorScheme: cs,
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static Offset _sceneFromMinimap(
    Offset local,
    Size box,
    Scene scene,
  ) {
    final bounds = _sceneBounds(scene);
    final pad = 6.0;
    final inner = Rect.fromLTWH(pad, pad, box.width - pad * 2, box.height - pad * 2);
    final nx = ((local.dx - inner.left) / inner.width).clamp(0.0, 1.0);
    final ny = ((local.dy - inner.top) / inner.height).clamp(0.0, 1.0);
    return Offset(
      bounds.left + nx * bounds.width,
      bounds.top + ny * bounds.height,
    );
  }

  static Rect _sceneBounds(Scene scene) {
    var minX = 0.0;
    var minY = 0.0;
    var maxX = 1280.0;
    var maxY = 720.0;
    for (final o in scene.objects) {
      minX = minX < o.x ? minX : o.x - 40;
      minY = minY < o.y ? minY : o.y - 40;
      maxX = maxX > o.x ? maxX : o.x + 40;
      maxY = maxY > o.y ? maxY : o.y + 40;
    }
    if (scene.rooms.isNotEmpty) {
      for (final r in scene.rooms) {
        minX = minX < r.x ? minX : r.x;
        minY = minY < r.y ? minY : r.y;
        maxX = maxX > r.x + r.w ? maxX : r.x + r.w;
        maxY = maxY > r.y + r.h ? maxY : r.y + r.h;
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}

class _SceneMinimapPainter extends CustomPainter {
  _SceneMinimapPainter({
    required this.scene,
    required this.assets,
    this.viewportMatrix,
    required this.viewportSize,
    required this.colorScheme,
  });

  final Scene scene;
  final List<ProjectAsset> assets;
  final Matrix4? viewportMatrix;
  final Size viewportSize;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = 6.0;
    final inner = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(6)),
      Paint()..color = colorScheme.surfaceContainerHighest,
    );

    final bounds = SceneMinimapPanel._sceneBounds(scene);
    Offset map(Offset p) {
      final nx = bounds.width <= 1 ? 0.5 : (p.dx - bounds.left) / bounds.width;
      final ny = bounds.height <= 1 ? 0.5 : (p.dy - bounds.top) / bounds.height;
      return Offset(inner.left + nx * inner.width, inner.top + ny * inner.height);
    }

    final grid = Paint()
      ..color = colorScheme.outline.withValues(alpha: 0.2)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 4; i++) {
      final fx = inner.left + inner.width * i / 4;
      final fy = inner.top + inner.height * i / 4;
      canvas.drawLine(Offset(fx, inner.top), Offset(fx, inner.bottom), grid);
      canvas.drawLine(Offset(inner.left, fy), Offset(inner.right, fy), grid);
    }

    if (scene.rooms.isNotEmpty) {
      final roomPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      final roomBorder = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final r in scene.rooms) {
        final tl = map(Offset(r.x, r.y));
        final br = map(Offset(r.x + r.w, r.y + r.h));
        final rect = Rect.fromPoints(tl, br);
        canvas.drawRect(rect, roomPaint);
        canvas.drawRect(rect, roomBorder);
      }
    }

    for (final o in scene.objects) {
      if (!o.active || !o.visible) continue;
      final c = map(Offset(o.x, o.y));
      final dot = Paint()..color = colorScheme.primary;
      canvas.drawCircle(c, 3, dot);
    }

    if (viewportMatrix != null && viewportSize.width > 1 && viewportSize.height > 1) {
      final inv = Matrix4.inverted(viewportMatrix!);
      final tl = MatrixUtils.transformPoint(inv, Offset.zero);
      final br = MatrixUtils.transformPoint(inv, viewportSize.bottomRight(Offset.zero));
      var r = Rect.fromPoints(map(tl), map(br));
      r = r.intersect(inner);
      if (r.width > 2 && r.height > 2) {
        final vp = Paint()
          ..color = colorScheme.tertiary.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;
        final vpBorder = Paint()
          ..color = colorScheme.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawRect(r, vp);
        canvas.drawRect(r, vpBorder);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SceneMinimapPainter old) =>
      old.scene != scene ||
      old.viewportMatrix != viewportMatrix ||
      old.viewportSize != viewportSize;
}
