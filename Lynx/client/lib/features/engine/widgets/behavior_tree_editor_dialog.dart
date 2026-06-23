import 'dart:convert';

import 'package:flutter/material.dart';

/// Визуальный редактор Behavior Tree (волна 5b) — JSON → `rustBehaviorTree`.
Future<Map<String, dynamic>?> showBehaviorTreeEditor(
  BuildContext context, {
  Map<String, dynamic>? initial,
}) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => _BehaviorTreeEditorDialog(initial: initial),
  );
}

class _BehaviorTreeEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _BehaviorTreeEditorDialog({this.initial});

  @override
  State<_BehaviorTreeEditorDialog> createState() => _BehaviorTreeEditorDialogState();
}

class _BehaviorTreeEditorDialogState extends State<_BehaviorTreeEditorDialog> {
  late Map<String, dynamic> _root;
  late TextEditingController _jsonCtrl;

  @override
  void initState() {
    super.initState();
    _root = _normalizeRoot(widget.initial) ?? _defaultPatrolTree();
    _jsonCtrl = TextEditingController(text: const JsonEncoder.withIndent('  ').convert({'root': _root}));
  }

  Map<String, dynamic>? _normalizeRoot(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    if (raw.containsKey('root')) {
      final r = raw['root'];
      if (r is Map) return Map<String, dynamic>.from(r);
    }
    return Map<String, dynamic>.from(raw);
  }

  Map<String, dynamic> _defaultPatrolTree() => {
        'type': 'sequence',
        'children': [
          {
            'type': 'leaf_patrol',
            'min_x': 120,
            'max_x': 520,
            'speed': 80,
          },
        ],
      };

  void _syncJsonField() {
    _jsonCtrl.text = const JsonEncoder.withIndent('  ').convert({'root': _root});
  }

  void _applyJsonFromField() {
    try {
      final map = jsonDecode(_jsonCtrl.text) as Map<String, dynamic>;
      final r = _normalizeRoot(map);
      if (r != null) setState(() => _root = r);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON: $e')),
      );
    }
  }

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Behavior Tree'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Узлы: sequence, selector, inverter, leaf_patrol, leaf_wait, '
                'leaf_chase_x, leaf_set_velocity, leaf_idle',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              _NodeTile(
                node: _root,
                depth: 0,
                onChanged: () => setState(_syncJsonField),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jsonCtrl,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'JSON (root)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _applyJsonFromField,
                child: const Text('Применить JSON'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {'root': _root}),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _NodeTile extends StatelessWidget {
  final Map<String, dynamic> node;
  final int depth;
  final VoidCallback onChanged;
  const _NodeTile({required this.node, required this.depth, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final type = node['type'] as String? ?? 'leaf_idle';
    final pad = EdgeInsets.only(left: depth * 16.0, top: 4, bottom: 4);
    return Padding(
      padding: pad,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'type', isDense: true),
                items: const [
                  'sequence',
                  'selector',
                  'inverter',
                  'leaf_patrol',
                  'leaf_wait',
                  'leaf_chase_x',
                  'leaf_set_velocity',
                  'leaf_idle',
                ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  node.clear();
                  node['type'] = v;
                  if (v == 'sequence' || v == 'selector') {
                    node['children'] = <Map<String, dynamic>>[];
                  } else if (v == 'inverter') {
                    node['child'] = {'type': 'leaf_idle'};
                  } else if (v == 'leaf_patrol') {
                    node['min_x'] = 0;
                    node['max_x'] = 200;
                    node['speed'] = 80;
                  } else if (v == 'leaf_wait') {
                    node['duration'] = 1.0;
                  } else if (v == 'leaf_chase_x') {
                    node['speed'] = 120;
                  } else if (v == 'leaf_set_velocity') {
                    node['vx'] = 0;
                    node['vy'] = 0;
                  }
                  onChanged();
                },
              ),
              if (type == 'leaf_patrol') ...[
                _numField('min_x', node, onChanged),
                _numField('max_x', node, onChanged),
                _numField('speed', node, onChanged),
              ],
              if (type == 'leaf_wait') _numField('duration', node, onChanged),
              if (type == 'leaf_chase_x') _numField('speed', node, onChanged),
              if (type == 'leaf_set_velocity') ...[
                _numField('vx', node, onChanged),
                _numField('vy', node, onChanged),
              ],
              if (type == 'sequence' || type == 'selector') ...[
                ...(node['children'] as List? ?? []).cast<Map>().map((c) {
                  final m = Map<String, dynamic>.from(c as Map);
                  return _NodeTile(node: m, depth: depth + 1, onChanged: onChanged);
                }),
                TextButton.icon(
                  onPressed: () {
                    final ch = (node['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                    ch.add({'type': 'leaf_idle'});
                    node['children'] = ch;
                    onChanged();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Дочерний узел'),
                ),
              ],
              if (type == 'inverter' && node['child'] is Map)
                _NodeTile(
                  node: Map<String, dynamic>.from(node['child'] as Map),
                  depth: depth + 1,
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numField(String key, Map<String, dynamic> node, VoidCallback onChanged) {
    return TextFormField(
      initialValue: (node[key] as num?)?.toString() ?? '0',
      decoration: InputDecoration(labelText: key, isDense: true),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        node[key] = double.tryParse(v.replaceAll(',', '.')) ?? 0;
        onChanged();
      },
    );
  }
}
