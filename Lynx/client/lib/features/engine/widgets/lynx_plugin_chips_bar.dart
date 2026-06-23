import 'package:flutter/material.dart';

import '../../plugins/lynx_plugin_host.dart';

/// Индикатор активных плагинов под заголовком редактора.
class LynxPluginChipsBar extends StatelessWidget {
  const LynxPluginChipsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final chips = LynxPluginHost.instance.editorStatusChips();
    if (chips.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          Icon(Icons.extension, size: 14, color: cs.primary),
          for (final label in chips)
            Chip(
              label: Text(label, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: cs.primaryContainer.withValues(alpha: 0.85),
            ),
        ],
      ),
    );
  }
}
