import 'package:flutter/material.dart';

class EngineBottomDock extends StatelessWidget {
  final bool expanded;
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onToggleExpand;
  final List<String> consoleLines;
  final VoidCallback onClearConsole;
  final String? engineVersionLabel;

  const EngineBottomDock({
    super.key,
    required this.expanded,
    required this.tabIndex,
    required this.onTabChanged,
    required this.onToggleExpand,
    required this.consoleLines,
    required this.onClearConsole,
    this.engineVersionLabel,
  });

  static const int kTabTimeline = 0;
  static const int kTabConsole = 1;
  static const int kTabLog = 2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.outline.withValues(alpha: 0.35);

    if (!expanded) {
      return Material(
        color: cs.surfaceContainerHigh,
        child: InkWell(
          onTap: onToggleExpand,
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: border)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.keyboard_arrow_up, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Таймлайн · Консоль · Лог',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                ),
                if (engineVersionLabel != null) ...[
                  const Spacer(),
                  Text(
                    'ядро $engineVersionLabel',
                    style: TextStyle(fontSize: 11, color: cs.primary),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: cs.surfaceContainerHigh,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  _DockTab(
                    label: 'Таймлайн',
                    icon: Icons.timeline,
                    selected: tabIndex == kTabTimeline,
                    onTap: () => onTabChanged(kTabTimeline),
                  ),
                  _DockTab(
                    label: 'Консоль',
                    icon: Icons.terminal,
                    selected: tabIndex == kTabConsole,
                    onTap: () => onTabChanged(kTabConsole),
                  ),
                  _DockTab(
                    label: 'Лог',
                    icon: Icons.list_alt,
                    selected: tabIndex == kTabLog,
                    onTap: () => onTabChanged(kTabLog),
                  ),
                  const Spacer(),
                  if (engineVersionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        engineVersionLabel!,
                        style: TextStyle(fontSize: 11, color: cs.primary),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Свернуть',
                    icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                    onPressed: onToggleExpand,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Expanded(
              child: switch (tabIndex) {
                kTabTimeline => _TimelinePlaceholder(cs: cs),
                kTabConsole => _ConsoleView(
                    lines: consoleLines,
                    onClear: onClearConsole,
                    cs: cs,
                  ),
                _ => _LogPlaceholder(cs: cs),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DockTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePlaceholder extends StatelessWidget {
  final ColorScheme cs;

  const _TimelinePlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Таймлайн анимаций и аудио-клипов будет привязан к клипам сущностей и шине микшера. '
        'Сейчас используйте Anim State Machine в инспекторе и project.json.',
        style: TextStyle(color: cs.onSurfaceVariant, height: 1.45, fontSize: 13),
      ),
    );
  }
}

class _LogPlaceholder extends StatelessWidget {
  final ColorScheme cs;

  const _LogPlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Системный лог сборки и синхронизации — в терминале CI и в SnackBar приложения. '
        'Сообщения Lua из предпросмотра дублируются во вкладке «Консоль».',
        style: TextStyle(color: cs.onSurfaceVariant, height: 1.45, fontSize: 13),
      ),
    );
  }
}

class _ConsoleView extends StatelessWidget {
  final List<String> lines;
  final VoidCallback onClear;
  final ColorScheme cs;

  const _ConsoleView({
    required this.lines,
    required this.onClear,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              TextButton(onPressed: onClear, child: const Text('Очистить')),
              const Spacer(),
              Text('${lines.length} строк', style: TextStyle(fontSize: 11, color: cs.outline)),
            ],
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFF12101a)),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: lines.length,
              itemBuilder: (_, i) {
                final t = lines[i];
                return SelectableText(
                  t,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.25,
                    color: Color(0xFFB8E0C8),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
