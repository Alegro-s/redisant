import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../runtime/entity_render_sort.dart';

class SceneGrid extends StatefulWidget {
  final List<Map<String, dynamic>> entities;
  final Function(Offset position) onPlaceEntity;
  final Function(int entityId, Offset newPosition) onEntityMoved;
  final int? selectedEntityId;
  final Function(int entityId) onEntitySelected;
  const SceneGrid({super.key, required this.entities, required this.onPlaceEntity, required this.onEntityMoved, required this.selectedEntityId, required this.onEntitySelected});
  @override
  State<SceneGrid> createState() => _SceneGridState();
}
class _SceneGridState extends State<SceneGrid> {
  final double cellSize = 40.0;
  int? _draggedEntityId;
  bool _isDragging = false;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (details) {
            final localPos = details.localPosition;
            final gridPos = Offset(
              (localPos.dx / cellSize).round() * cellSize,
              (localPos.dy / cellSize).round() * cellSize,
            );
            for (var entity in widget.entities) {
              final transform = entity['transform'] as Map<String, dynamic>;
              final pos = transform['pos'] as Map<String, dynamic>;
              final size = transform['size'] as Map<String, dynamic>;
              final rect = Rect.fromCenter(
                center: Offset(pos['x'].toDouble(), pos['y'].toDouble()),
                width: size['x'].toDouble(),
                height: size['y'].toDouble(),
              );
              if (rect.contains(localPos)) {
                setState(() {
                  _draggedEntityId = entity['id'] as int;
                });
                widget.onEntitySelected(entity['id'] as int);
                return;
              }
            }
            widget.onPlaceEntity(gridPos);
          },
          onPanUpdate: (details) {
            if (_draggedEntityId != null) {
              setState(() { _isDragging = true; });
            }
          },
          onPanEnd: (details) {
            if (_draggedEntityId != null && _isDragging) {
              final newPos = Offset(
                (details.localPosition.dx / cellSize).round() * cellSize,
                (details.localPosition.dy / cellSize).round() * cellSize,
              );
              widget.onEntityMoved(_draggedEntityId!, newPos);
            }
            setState(() {
              _draggedEntityId = null;
              _isDragging = false;
            });
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: ScenePainter(
              entities: widget.entities,
              cellSize: cellSize,
              selectedEntityId: widget.selectedEntityId,
            ),
          ),
        );
      },
    );
  }
}
class ScenePainter extends CustomPainter {
  final List<Map<String, dynamic>> entities;
  final double cellSize;
  final int? selectedEntityId;
  ScenePainter({required this.entities, required this.cellSize, this.selectedEntityId});
  @override
  void paint(Canvas canvas, ui.Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey.shade800);
    final gridPaint = Paint()..color = Colors.white24..strokeWidth = 0.5;
    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var entity in sortedEntitiesForRender(entities)) {
      final transform = entity['transform'] as Map<String, dynamic>;
      final pos = transform['pos'] as Map<String, dynamic>;
      final sizeMap = transform['size'] as Map<String, dynamic>;
      final sprite = entity['sprite'] as Map<String, dynamic>;
      final colorHex = sprite['color_hex'] as int;
      final color = Color(colorHex).withOpacity(1.0);
      final rect = Rect.fromCenter(
        center: Offset(pos['x'].toDouble(), pos['y'].toDouble()),
        width: sizeMap['x'].toDouble(),
        height: sizeMap['y'].toDouble(),
      );
      canvas.drawRect(rect, Paint()..color = color);
      if (entity['id'] == selectedEntityId) {
        final outlinePaint = Paint()..color = Colors.cyan..style = PaintingStyle.stroke..strokeWidth = 2.0;
        canvas.drawRect(rect, outlinePaint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.entities != entities || oldDelegate.selectedEntityId != selectedEntityId;
  }
}