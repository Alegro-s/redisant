import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../lynx_built_games_registry.dart';

/// L22a — список последних сборок с кнопкой «Открыть / Скачать».
class LynxBuiltGamesPanel extends StatefulWidget {
  const LynxBuiltGamesPanel({super.key, this.projectPathFilter});

  final String? projectPathFilter;

  @override
  State<LynxBuiltGamesPanel> createState() => _LynxBuiltGamesPanelState();
}

class _LynxBuiltGamesPanelState extends State<LynxBuiltGamesPanel> {
  List<LynxBuiltGameRecord> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    var all = await LynxBuiltGamesRegistry.loadAll();
    final filter = widget.projectPathFilter;
    if (filter != null && filter.isNotEmpty) {
      all = all.where((r) => r.projectPath == filter).toList();
    }
    if (mounted) {
      setState(() {
        _records = all;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Собранных игр пока нет. Соберите проект в Engine → Export.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text('Собранные игры', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Обновить',
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
        ),
        for (final r in _records.take(8))
          ListTile(
            dense: true,
            leading: Icon(_iconFor(r.preset)),
            title: Text(r.projectName.isEmpty ? r.outputDirectory : r.projectName),
            subtitle: Text('${r.preset.name} · ${_fmt(r.builtAt)}'),
            trailing: FilledButton.tonal(
              onPressed: () => LynxBuiltGamesRegistry.openPrimaryArtifact(r),
              child: const Text('Открыть'),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(dynamic preset) {
    final name = preset.toString();
    if (name.contains('windows')) return Icons.desktop_windows_outlined;
    if (name.contains('android')) return Icons.android_outlined;
    if (name.contains('cart')) return Icons.inventory_2_outlined;
    if (name.contains('web')) return Icons.language_outlined;
    return Icons.folder_outlined;
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
