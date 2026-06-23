import 'package:flutter/material.dart';

class CenteredIconRow extends StatelessWidget {
  const CenteredIconRow({
    super.key,
    required this.itemWidth,
    required this.gap,
    required this.height,
    required this.children,
  });

  final double itemWidth;
  final double gap;
  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = children.length;
        final totalW = count * itemWidth + (count > 1 ? (count - 1) * gap : 0);
        final sidePad = ((constraints.maxWidth - totalW) / 2).clamp(0.0, double.infinity);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: sidePad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  SizedBox(width: itemWidth, child: children[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
