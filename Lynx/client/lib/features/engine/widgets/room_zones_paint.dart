import 'package:flutter/material.dart';

import '../models/engine_models.dart';

void paintRoomZonesEditor(Canvas canvas, List<RoomZoneData> rooms) {
  for (final r in rooms) {
    if (r.w <= 0 || r.h <= 0) continue;
    final rect = Rect.fromLTWH(r.x, r.y, r.w, r.h);
    canvas.drawRect(rect, Paint()..color = const Color(0x55FFC107));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFC107),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: r.id,
        style: const TextStyle(
          color: Color(0xFFFFECB3),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r.w.abs().clamp(40, 400));
    tp.paint(canvas, Offset(r.x + 4, r.y + 4));
  }
}

double _roomNum(Map<String, dynamic> m, String snake, String camel) {
  final a = m[snake];
  if (a is num) return a.toDouble();
  final b = m[camel];
  if (b is num) return b.toDouble();
  return 0;
}

void paintRustRoomZonesWorld({
  required Canvas canvas,
  required List<Map<String, dynamic>> rooms,
  required Offset Function(double wx, double wy) worldToScreen,
}) {
  for (final raw in rooms) {
    final m = Map<String, dynamic>.from(raw);
    final x = _roomNum(m, 'x', 'x');
    final y = _roomNum(m, 'y', 'y');
    final w = _roomNum(m, 'w', 'w');
    final h = _roomNum(m, 'h', 'h');
    if (w <= 0 || h <= 0) continue;
    final id = m['id']?.toString() ?? 'room';
    final tl = worldToScreen(x, y);
    final br = worldToScreen(x + w, y + h);
    final rect = Rect.fromPoints(tl, br);
    canvas.drawRect(rect, Paint()..color = const Color(0x44FF9800));
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFF9800).withValues(alpha: 0.9),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: id,
        style: const TextStyle(
          color: Color(0xFFFFE0B2),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width.abs().clamp(32, 280));
    tp.paint(canvas, Offset(rect.left + 3, rect.top + 2));
  }
}
