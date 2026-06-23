import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/engine_workspace_provider.dart';
import 'console_workspace_panels.dart';
import '../widgets/engine_scene_viewport_controller.dart';

/// TIC-80 плотность: Код · Спрайт · Карта · Звук · Музыка · Play (волна 17).
class ConsoleModeShell extends StatelessWidget {
  const ConsoleModeShell({
    super.key,
    required this.projectRoot,
    required this.onExitConsole,
    this.viewportController,
    this.onConsoleLine,
    this.previewActive = true,
  });

  final String? projectRoot;
  final VoidCallback onExitConsole;
  final EngineSceneViewportController? viewportController;
  final void Function(String line)? onConsoleLine;
  final bool previewActive;

  static const _tabs = [
    ('Код', Icons.code),
    ('Спрайт', Icons.grid_on),
    ('Карта', Icons.map_outlined),
    ('Звук', Icons.graphic_eq),
    ('Музыка', Icons.music_note),
    ('Play', Icons.play_arrow),
  ];

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<EngineWorkspaceProvider>();
    final tab = ws.consoleTab;

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                const Text('Консоль', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onExitConsole,
                  icon: const Icon(Icons.view_in_ar, size: 18),
                  label: const Text('Проект'),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    label: Text(_tabs[i].$1),
                    avatar: Icon(_tabs[i].$2, size: 18),
                    selected: tab == i,
                    onSelected: (_) => ws.setConsoleTab(i),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _bodyForTab(context, tab)),
      ],
    );
  }

  Widget _bodyForTab(BuildContext context, int tab) {
    return ConsoleWorkspacePanels(
      tab: tab,
      projectRoot: projectRoot,
      viewportController: viewportController,
      onConsoleLine: onConsoleLine,
      previewActive: previewActive,
    );
  }
}
