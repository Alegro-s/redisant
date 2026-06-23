import 'package:flutter/material.dart';

import '../themes/lynx_hub_palette.dart';

class LynxMark extends StatelessWidget {
  const LynxMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LynxMarkPainter()),
    );
  }
}

class _LynxMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.125;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.06, size.height * 0.06, size.width * 0.88, size.height * 0.88),
      Radius.circular(r),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LynxHubPalette.markTop, LynxHubPalette.markBottom],
        ).createShader(rect.outerRect),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.024
        ..color = LynxHubPalette.accentSoft,
    );
    final tri = Path()
      ..moveTo(size.width * 0.28, size.height * 0.72)
      ..lineTo(size.width * 0.5, size.height * 0.28)
      ..lineTo(size.width * 0.72, size.height * 0.72)
      ..close();
    canvas.drawPath(tri, Paint()..color = LynxHubPalette.accent.withValues(alpha: 0.22));
    canvas.drawPath(
      tri,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.055
        ..strokeJoin = StrokeJoin.round
        ..color = LynxHubPalette.accentSoft,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'L',
        style: TextStyle(
          color: LynxHubPalette.text,
          fontSize: size.width * 0.26,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.width * 0.5 - tp.width / 2, size.height * 0.52 - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
