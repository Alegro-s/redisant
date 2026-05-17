import 'package:flutter/material.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';

class EngineProjectSettingsDialog extends StatefulWidget {
  const EngineProjectSettingsDialog({super.key, required this.manager});

  final ProjectManager manager;

  @override
  State<EngineProjectSettingsDialog> createState() =>
      _EngineProjectSettingsDialogState();
}

class _EngineProjectSettingsDialogState
    extends State<EngineProjectSettingsDialog> {
  late double _master;
  late Map<String, double> _buses;
  late List<ProjectTileset> _tilesets;
  final _newBusName = TextEditingController();
  final _tsId = TextEditingController();
  final _tsPath = TextEditingController();
  final _tsCols = TextEditingController(text: '16');

  @override
  void initState() {
    super.initState();
    final p = widget.manager.projectSettings!;
    _master = p.audioMasterVolume;
    _buses = Map<String, double>.from(p.audioBusVolumes);
    _tilesets = List<ProjectTileset>.from(p.tilesets);
  }

  @override
  void dispose() {
    _newBusName.dispose();
    _tsId.dispose();
    _tsPath.dispose();
    _tsCols.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final base = widget.manager.projectSettings!;
    await widget.manager.saveProjectSettings(
      base.copyWith(
        audioMasterVolume: _master,
        audioBusVolumes: _buses,
        tilesets: _tilesets,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final busKeys = _buses.keys.toList()..sort();
    return AlertDialog(
      title: const Text('Проект: микшер и тайлсеты'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Аудио (без DSP — только громкости, как в экспорте сцены)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 88, child: Text('Master')),
                  Expanded(
                    child: Slider(
                      value: _master.clamp(0.0, 1.0),
                      onChanged: (v) => setState(() => _master = v),
                    ),
                  ),
                  SizedBox(width: 40, child: Text(_master.toStringAsFixed(2))),
                ],
              ),
              const Divider(),
              const Text('Шины (имя → множитель)'),
              const SizedBox(height: 6),
              for (final k in busKeys)
                Row(
                  children: [
                    SizedBox(width: 100, child: Text(k, overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: Slider(
                        value: (_buses[k] ?? 1.0).clamp(0.0, 2.0),
                        max: 2.0,
                        onChanged: (v) => setState(() => _buses[k] = v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => setState(() => _buses.remove(k)),
                    ),
                  ],
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newBusName,
                      decoration: const InputDecoration(
                        labelText: 'Новая шина',
                        isDense: true,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      final n = _newBusName.text.trim();
                      if (n.isEmpty) return;
                      setState(() {
                        _buses[n] = 1.0;
                        _newBusName.clear();
                      });
                    },
                    child: const Text('Добавить'),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text('Тайлсеты (id + путь к PNG от корня проекта)'),
              const SizedBox(height: 6),
              for (var i = 0; i < _tilesets.length; i++)
                ListTile(
                  dense: true,
                  title: Text(_tilesets[i].id),
                  subtitle: Text(_tilesets[i].texturePath),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _tilesets.removeAt(i)),
                  ),
                ),
              TextField(
                controller: _tsId,
                decoration: const InputDecoration(labelText: 'id', isDense: true),
              ),
              TextField(
                controller: _tsPath,
                decoration: const InputDecoration(
                  labelText: 'texturePath (напр. assets/sprites/tiles.png)',
                  isDense: true,
                ),
              ),
              TextField(
                controller: _tsCols,
                decoration: const InputDecoration(labelText: 'columns', isDense: true),
                keyboardType: TextInputType.number,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () {
                    final id = _tsId.text.trim();
                    final path = _tsPath.text.trim();
                    if (id.isEmpty || path.isEmpty) return;
                    final c = int.tryParse(_tsCols.text.trim()) ?? 16;
                    setState(() {
                      _tilesets.add(ProjectTileset(id: id, texturePath: path, columns: c.clamp(1, 256)));
                      _tsId.clear();
                      _tsPath.clear();
                    });
                  },
                  child: const Text('Добавить тайлсет'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _save, child: const Text('Сохранить в project.json')),
      ],
    );
  }
}
