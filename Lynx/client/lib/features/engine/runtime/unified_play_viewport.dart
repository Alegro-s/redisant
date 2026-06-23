import 'dart:math' as math;

import 'package:flutter/material.dart';

/// E20 — единый viewport для Preview и Play (pixel-perfect / letterbox).
class UnifiedPlayViewport extends StatelessWidget {
  const UnifiedPlayViewport({
    super.key,
    required this.designWidth,
    required this.designHeight,
    required this.child,
    this.pixelPerfect = false,
    this.backgroundColor,
  });

  final double designWidth;
  final double designHeight;
  final bool pixelPerfect;
  final Widget child;
  final Color? backgroundColor;

  static double letterboxScale({
    required double maxWidth,
    required double maxHeight,
    required double designWidth,
    required double designHeight,
  }) {
    if (designWidth <= 0 || designHeight <= 0) return 1;
    return math.min(maxWidth / designWidth, maxHeight / designHeight);
  }

  /// E20b — pixel-perfect: целочисленный upscale для cart/console.
  static double resolvePlayScale({
    required double maxWidth,
    required double maxHeight,
    required double designWidth,
    required double designHeight,
    required bool pixelPerfect,
  }) {
    final raw = letterboxScale(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      designWidth: designWidth,
      designHeight: designHeight,
    );
    if (!pixelPerfect) return raw.clamp(0.05, 8.0);
    if (raw >= 1.0) {
      return math.max(1.0, raw.floorToDouble());
    }
    return raw.clamp(0.05, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bg = backgroundColor ?? Colors.black;
        if (!pixelPerfect) {
          return ColoredBox(
            color: bg,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          );
        }
        final scale = letterboxScale(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
          designWidth: designWidth,
          designHeight: designHeight,
        );
        final w = designWidth * scale;
        final h = designHeight * scale;
        return ColoredBox(
          color: bg,
          child: Center(
            child: SizedBox(
              width: w,
              height: h,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: designWidth,
                  height: designHeight,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Снимок viewport для snapshot-тестов (E20c).
Map<String, dynamic> unifiedViewportSnapshot({
  required double designWidth,
  required double designHeight,
  required bool pixelPerfect,
  required double hostWidth,
  required double hostHeight,
}) {
  final scale = pixelPerfect
      ? UnifiedPlayViewport.resolvePlayScale(
          maxWidth: hostWidth,
          maxHeight: hostHeight,
          designWidth: designWidth,
          designHeight: designHeight,
          pixelPerfect: true,
        )
      : 1.0;
  return {
    'designWidth': designWidth,
    'designHeight': designHeight,
    'pixelPerfect': pixelPerfect,
    'scale': scale,
    'viewportWidth': pixelPerfect ? designWidth * scale : hostWidth,
    'viewportHeight': pixelPerfect ? designHeight * scale : hostHeight,
  };
}
