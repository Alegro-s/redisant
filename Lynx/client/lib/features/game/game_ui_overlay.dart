import 'package:flutter/material.dart';

/// Flutter-слой UI поверх Play (волна 5c → 10c themes).
class GameUiOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> widgets;
  final double viewWidth;
  final double viewHeight;
  final double cameraX;
  final double cameraY;
  final double paintZoom;
  final void Function(String action)? onAction;

  const GameUiOverlay({
    super.key,
    required this.widgets,
    required this.viewWidth,
    required this.viewHeight,
    required this.cameraX,
    required this.cameraY,
    required this.paintZoom,
    this.onAction,
  });

  double _sx(double wx) => viewWidth / 2 + (wx - cameraX) * paintZoom;
  double _sy(double wy) => viewHeight / 2 + (wy - cameraY) * paintZoom;

  @override
  Widget build(BuildContext context) {
    if (widgets.isEmpty) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final w in widgets)
          Positioned(
            left: _sx((w['x'] as num).toDouble()) - ((w['w'] as num).toDouble() * paintZoom) / 2,
            top: _sy((w['y'] as num).toDouble()) - ((w['h'] as num).toDouble() * paintZoom) / 2,
            width: (w['w'] as num).toDouble() * paintZoom,
            height: (w['h'] as num).toDouble() * paintZoom,
            child: _buildWidget(context, w),
          ),
      ],
    );
  }

  Widget _buildWidget(BuildContext context, Map<String, dynamic> w) {
    final type = w['type'] as String? ?? 'label';
    final text = w['text'] as String? ?? '';
    final theme = w['theme'] as String? ?? 'dark';
    final light = theme == 'light';

    if (type == 'button') {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: light ? Colors.white : const Color(0xFF238636),
          foregroundColor: light ? Colors.black87 : Colors.white,
        ),
        onPressed: () {
          final action = w['action'] as String?;
          if (action != null && onAction != null) onAction!(action);
        },
        child: Text(text, textAlign: TextAlign.center),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: light ? Colors.white70 : Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: light ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
