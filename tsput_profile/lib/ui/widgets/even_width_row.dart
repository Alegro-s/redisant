import 'package:flutter/material.dart';

class EvenWidthRow extends StatelessWidget {
  const EvenWidthRow({
    super.key,
    required this.height,
    required this.children,
    this.gap = 8,
  });

  final double height;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}
