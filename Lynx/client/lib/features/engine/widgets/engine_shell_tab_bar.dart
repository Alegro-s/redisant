import 'package:flutter/material.dart';

/// Верхние вкладки Lynx Engine: Проект · Сцена · Код · Ассеты · Play · Сборка (E16b).
class EngineShellTabBar extends StatelessWidget implements PreferredSizeWidget {
  const EngineShellTabBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  static const labels = ['Проект', 'Сцена', 'Код', 'Ассеты', 'Play', 'Сборка'];

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(labels[i]),
                  selected: index == i,
                  onSelected: (_) => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
