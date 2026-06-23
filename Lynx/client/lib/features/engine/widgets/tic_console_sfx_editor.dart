import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Compact TIC SFX editor — 8 channels, note/volume/duration per slot.
class TicConsoleSfxEditor extends StatefulWidget {
  const TicConsoleSfxEditor({super.key, required this.projectRoot});

  final String projectRoot;

  @override
  State<TicConsoleSfxEditor> createState() => _TicConsoleSfxEditorState();
}

class _TicConsoleSfxEditorState extends State<TicConsoleSfxEditor> {
  final List<_SfxSlot> _slots = List.generate(32, (_) => _SfxSlot());
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = File(p.join(widget.projectRoot, 'assets', 'tic', 'sfx.json'));
    if (await f.exists()) {
      try {
        final raw = jsonDecode(await f.readAsString());
        if (raw is List) {
          for (var i = 0; i < raw.length && i < _slots.length; i++) {
            if (raw[i] is Map) {
              _slots[i] = _SfxSlot.fromJson(Map<String, dynamic>.from(raw[i] as Map));
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
    final payload = jsonEncode(_slots.map((s) => s.toJson()).toList());
    await File(p.join(dir.path, 'sfx.json')).writeAsString(payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SFX сохранены')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Сохранить'),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _slots.length,
            itemBuilder: (context, i) {
              final s = _slots[i];
              return ListTile(
                dense: true,
                title: Text('SFX $i'),
                subtitle: Text('note ${s.note} · vol ${s.volume} · ${s.duration} ticks'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editSlot(i),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _editSlot(int i) async {
    final s = _slots[i];
    final note = TextEditingController(text: '${s.note}');
    final vol = TextEditingController(text: '${s.volume}');
    final dur = TextEditingController(text: '${s.duration}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SFX $i'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Note')),
            TextField(controller: vol, decoration: const InputDecoration(labelText: 'Volume 0-15')),
            TextField(controller: dur, decoration: const InputDecoration(labelText: 'Duration')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _slots[i] = _SfxSlot(
          note: int.tryParse(note.text) ?? s.note,
          volume: int.tryParse(vol.text)?.clamp(0, 15) ?? s.volume,
          duration: int.tryParse(dur.text) ?? s.duration,
        );
      });
    }
  }
}

class _SfxSlot {
  final int note;
  final int volume;
  final int duration;
  const _SfxSlot({this.note = 0, this.volume = 15, this.duration = 10});

  factory _SfxSlot.fromJson(Map<String, dynamic> j) => _SfxSlot(
        note: (j['note'] as num?)?.toInt() ?? 0,
        volume: (j['volume'] as num?)?.toInt() ?? 15,
        duration: (j['duration'] as num?)?.toInt() ?? 10,
      );

  Map<String, dynamic> toJson() => {
        'note': note,
        'volume': volume,
        'duration': duration,
      };
}
