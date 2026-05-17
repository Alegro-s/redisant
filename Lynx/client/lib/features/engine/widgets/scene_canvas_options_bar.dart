import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../project_manager.dart';
import '../providers/scene_provider.dart';

class SceneCanvasOptionsBar extends StatelessWidget {
  const SceneCanvasOptionsBar({super.key});

  static const List<double> _presets = [1, 2, 4, 8, 16, 32, 40, 64];

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SceneProvider>();
    final mgr = context.watch<ProjectManager>();
    final step = sp.objectSnapStep;
    final opts = {..._presets, step}.toList()..sort();
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Text(
              'Привязка объектов',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('Комнаты'),
              selected: sp.showRoomZones,
              visualDensity: VisualDensity.compact,
              onSelected: mgr.isCloudReadOnly
                  ? null
                  : (v) => context.read<SceneProvider>().setShowRoomZones(v),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: DropdownButtonFormField<double>(
                    isDense: true,
                    isExpanded: true,
                    value: step,
                    decoration: const InputDecoration(
                      labelText: 'Шаг (px)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      for (final x in opts)
                        DropdownMenuItem(
                          value: x,
                          child: Text('${x % 1 == 0 ? x.toInt() : x} px'),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) context.read<SceneProvider>().setObjectSnapStep(v);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
