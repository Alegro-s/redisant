import 'dart:convert';

import 'package:flutter/material.dart';

import '../runtime/lynx_graph_compiler.dart';
import '../runtime/lynx_graph_model.dart';

/// Visual Blueprint editor (LynxGraph → LynxScript).
Future<LynxGraphDocument?> showLynxBlueprintEditor(
  BuildContext context, {
  LynxGraphDocument? initial,
}) async {
  return showDialog<LynxGraphDocument>(
    context: context,
    builder: (ctx) => _LynxBlueprintEditorDialog(initial: initial),
  );
}

class _LynxBlueprintEditorDialog extends StatefulWidget {
  final LynxGraphDocument? initial;
  const _LynxBlueprintEditorDialog({this.initial});

  @override
  State<_LynxBlueprintEditorDialog> createState() => _LynxBlueprintEditorDialogState();
}

class _LynxBlueprintEditorDialogState extends State<_LynxBlueprintEditorDialog> {
  late LynxGraphDocument _doc;
  late TextEditingController _scriptCtrl;
  String? _compileErr;

  @override
  void initState() {
    super.initState();
    _doc = widget.initial ?? LynxGraphDocument.defaultPlayerController();
    _scriptCtrl = TextEditingController(text: _compilePreview());
  }

  String _compilePreview() {
    try {
      _compileErr = null;
      return compileLynxGraphToScript(_doc);
    } catch (e) {
      _compileErr = e.toString();
      return '#lynxscript\n-- error: $_compileErr';
    }
  }

  void _syncPreview() => setState(() => _scriptCtrl.text = _compilePreview());

  void _addSetVelocity() {
    setState(() {
      _doc = LynxGraphDocument(
        statements: [..._doc.statements, LynxGraphStatement.setVelocity('0', 'vy')],
      );
      _syncPreview();
    });
  }

  void _addIfKey(String key) {
    setState(() {
      _doc = LynxGraphDocument(
        statements: [
          ..._doc.statements,
          LynxGraphStatement.ifCond(key, [
            LynxGraphStatement.setVelocity(key == 'key_a' ? '-260' : '260', 'vy'),
          ]),
        ],
      );
      _syncPreview();
    });
  }

  void _removeAt(int index) {
    setState(() {
      final next = [..._doc.statements]..removeAt(index);
      _doc = LynxGraphDocument(statements: next);
      _syncPreview();
    });
  }

  @override
  void dispose() {
    _scriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Blueprint (LynxGraph)'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Визуальные блоки компилируются в LynxScript (#lynxscript). '
                'Узлы: set_velocity, if key_a/key_d/on_ground/action_pressed.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(onPressed: _addSetVelocity, child: const Text('+ set_velocity')),
                  OutlinedButton(onPressed: () => _addIfKey('key_a'), child: const Text('+ if key_a')),
                  OutlinedButton(onPressed: () => _addIfKey('key_d'), child: const Text('+ if key_d')),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _doc = LynxGraphDocument.defaultPlayerController();
                        _syncPreview();
                      });
                    },
                    child: const Text('Шаблон игрока'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(_doc.statements.length, (i) {
                final s = _doc.statements[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(_labelFor(s), style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _removeAt(i),
                    ),
                  ),
                );
              }),
              if (_compileErr != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_compileErr!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                ),
              TextField(
                controller: _scriptCtrl,
                readOnly: true,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'LynxScript preview',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: _compileErr == null ? () => Navigator.pop(context, _doc) : null,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  String _labelFor(LynxGraphStatement s) {
    if (s.type == 'set_velocity') return 'set_velocity(${s.vx}, ${s.vy})';
    if (s.type == 'if') {
      final head = s.cond == 'action_pressed' ? 'action_pressed("${s.actionName ?? "jump"}")' : s.cond;
      return 'if $head then (${s.children.length} blocks)';
    }
    return s.type;
  }
}

String lynxGraphToJson(LynxGraphDocument doc) =>
    const JsonEncoder.withIndent('  ').convert(doc.toJson());

LynxGraphDocument? lynxGraphFromJsonString(String raw) {
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return tryParseLynxGraphJson(map);
  } catch (_) {
    return null;
  }
}
