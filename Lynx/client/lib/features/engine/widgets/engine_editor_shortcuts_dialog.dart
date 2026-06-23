import 'package:flutter/material.dart';

class EngineShortcutEntry {
  final String keys;
  final String action;
  const EngineShortcutEntry(this.keys, this.action);
}

const List<EngineShortcutEntry> kEngineEditorShortcuts = [
  EngineShortcutEntry('Ctrl + +', 'Масштаб холста (вкладка «Сцена»)'),
  EngineShortcutEntry('Ctrl + −', 'Уменьшить холст'),
  EngineShortcutEntry('Ctrl + 0', 'Сбросить вид холста'),
  EngineShortcutEntry('Ctrl + Shift + +', 'Масштаб всего редактора'),
  EngineShortcutEntry('Ctrl + Shift + −', 'Уменьшить интерфейс редактора'),
  EngineShortcutEntry('Ctrl + Shift + 0', 'Интерфейс редактора 100%'),
  EngineShortcutEntry('Ctrl + колёсико / тачпад', 'Zoom холста под курсором'),
  EngineShortcutEntry('Ctrl + S', 'Сохранить сцену сейчас'),
  EngineShortcutEntry('Ctrl + Z', 'Отмена'),
  EngineShortcutEntry('Ctrl + Shift + Z / Ctrl + Y', 'Вернуть'),
  EngineShortcutEntry('Ctrl + 1 / 2 / 3', 'Вкладки: Сцена / Игра / Код'),
  EngineShortcutEntry('F5', 'Вкладка «Игра»'),
  EngineShortcutEntry('Delete', 'Удалить выбранный объект'),
  EngineShortcutEntry('Ctrl + D', 'Дублировать объект'),
  EngineShortcutEntry('Escape', 'Снять выделение'),
  EngineShortcutEntry('T', 'Режим кисти тайлов вкл/выкл'),
  EngineShortcutEntry('Ctrl + Shift + B', 'Blueprint (LynxGraph) для выбранного скрипта'),
  EngineShortcutEntry('Ctrl + Shift + N', 'Новый Lua-скрипт'),
  EngineShortcutEntry('Ctrl + Shift + I', 'Новый спрайт'),
  EngineShortcutEntry('Ctrl + /  или  F1', 'Эта шпаргалка'),
];

Future<void> showEngineEditorShortcutsDialog(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Горячие клавиши Lynx Editor'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            children: [
              for (final e in kEngineEditorShortcuts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 168,
                        child: Text(
                          e.keys,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.action,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}
