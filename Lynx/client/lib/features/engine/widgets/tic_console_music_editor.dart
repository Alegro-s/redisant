import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Compact TIC music tracker — rows of note slots per track.
class TicConsoleMusicEditor extends StatefulWidget {
  const TicConsoleMusicEditor({super.key, required this.projectRoot});

  final String projectRoot;

  @override
  State<TicConsoleMusicEditor> createState() => _TicConsoleMusicEditorState();
}

class _TicConsoleMusicEditorState extends State<TicConsoleMusicEditor> {
  final List<List<int>> _tracks = List.generate(8, (_) => List.filled(64, -1));
  int _track = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = File(p.join(widget.projectRoot, 'assets', 'tic', 'music.json'));
    if (await f.exists()) {
      try {
        final raw = jsonDecode(await f.readAsString());
        if (raw is List) {
          for (var t = 0; t < raw.length && t < _tracks.length; t++) {
            if (raw[t] is List) {
              final row = (raw[t] as List).map((e) => (e as num).toInt()).toList();
              for (var i = 0; i < row.length && i < _tracks[t].length; i++) {
                _tracks[t][i] = row[i];
              }
            }
          }
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final dir = Directory(p.join(widget.projectRoot, 'assets', 'tic'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'music.json')).writeAsString(jsonEncode(_tracks));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Музыка сохранена')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final rows = _tracks[_track];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Трек'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _track,
                items: List.generate(
                  _tracks.length,
                  (i) => DropdownMenuItem(value: i, child: Text('$i')),
                ),
                onChanged: (v) => setState(() => _track = v ?? 0),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 16,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final n = rows[i];
              return InkWell(
                onTap: () => _editNote(i),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: n < 0 ? Colors.black26 : Colors.blueGrey,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(
                      n < 0 ? '·' : '$n',
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editNote(int row) async {
    final ctrl = TextEditingController(
      text: _tracks[_track][row] < 0 ? '' : '${_tracks[_track][row]}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Трек $_track · строка $row'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Note (-1 = rest)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _tracks[_track][row] = int.tryParse(ctrl.text) ?? -1;
      });
    }
  }
}
