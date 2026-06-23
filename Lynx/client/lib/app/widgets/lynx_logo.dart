import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lynx_mark.dart';

class LynxLogo extends StatelessWidget {
  const LynxLogo({
    super.key,
    this.size = 40,
    this.showWordmark = true,
    this.compact = false,
  });

  final double size;
  final bool showWordmark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mark = LynxMark(size: size);

    if (!showWordmark) return mark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: compact ? 6 : 8),
        Text(
          'Lynx',
          style: GoogleFonts.montserrat(
            fontSize: compact ? 16 : 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: cs.onSurface,
          ).copyWith(inherit: false),
        ),
        if (!compact)
          Text(
            'Launcher',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ).copyWith(inherit: false),
          ),
      ],
    );
  }
}
