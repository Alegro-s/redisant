import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../project_manager.dart';
import '../providers/scene_provider.dart';

/// Вкладки сцен проекта — отдельный холст на каждую сцену.
class SceneScenesTabBar extends StatelessWidget {
  const SceneScenesTabBar({super.key});

  Future<void> _createScene(BuildContext context) async {
    final mgr = context.read<ProjectManager>();
    final sp = context.read<SceneProvider>();
    if (mgr.isCloudReadOnly || mgr.rootPath == null) return;
    final ctrl = TextEditingController(text: 'Room ${mgr.scenes.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая сцена'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Имя сцены',
            hintText: 'menu, level_1, boss_room',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;
    mgr.scheduleSceneSave();
    final scene = await mgr.createScene(name);
    if (!context.mounted) return;
    sp.setCurrentScene(scene);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сцена «$name» создана')),
    );
  }

  void _switchScene(BuildContext context, SceneProvider sp, ProjectManager mgr, int index) {
    if (index < 0 || index >= mgr.scenes.length) return;
    mgr.scheduleSceneSave();
    sp.setCurrentScene(mgr.scenes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProjectManager, SceneProvider>(
      builder: (context, mgr, sp, _) {
        final cs = Theme.of(context).colorScheme;
        final scenes = mgr.scenes;
        if (scenes.isEmpty) return const SizedBox.shrink();
        final current = sp.currentScene;
        final currentIndex = current == null
            ? 0
            : scenes.indexWhere((s) => s.id == current.id).clamp(0, scenes.length - 1);

        return Material(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.92),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4),
                  child: Text(
                    'Холсты',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: scenes.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, i) {
                      final s = scenes[i];
                      final selected = i == currentIndex;
                      return Material(
                        color: selected
                            ? cs.primaryContainer.withValues(alpha: 0.55)
                            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _switchScene(context, sp, mgr, i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text(
                              s.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!mgr.isCloudReadOnly)
                  IconButton(
                    tooltip: 'Новая сцена (комната / уровень)',
                    icon: const Icon(Icons.add_box_outlined, size: 20),
                    onPressed: () => _createScene(context),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}
