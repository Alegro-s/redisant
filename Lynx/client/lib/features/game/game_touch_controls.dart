import 'package:flutter/material.dart';

class GameHoldButton extends StatelessWidget {
  const GameHoldButton({
    super.key,
    required this.onHold,
    required this.onRelease,
    required this.icon,
    this.size = 52,
  });

  final VoidCallback onHold;
  final VoidCallback onRelease;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Listener(
      onPointerDown: (_) => onHold(),
      onPointerUp: (_) => onRelease(),
      onPointerCancel: (_) => onRelease(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.92),
          border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: size * 0.44, color: cs.onSurface),
      ),
    );
  }
}
