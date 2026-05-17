import 'dart:convert';

import 'package:client/features/assets/providers/asset_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/lua.dart';
import 'package:provider/provider.dart';

class CloudScriptEditorScreen extends StatefulWidget {
  final String projectId;
  final String assetId;
  final String title;
  final bool readOnly;

  const CloudScriptEditorScreen({
    super.key,
    required this.projectId,
    required this.assetId,
    required this.title,
    this.readOnly = false,
  });

  @override
  State<CloudScriptEditorScreen> createState() => _CloudScriptEditorScreenState();
}

class _CloudScriptEditorScreenState extends State<CloudScriptEditorScreen> {
  CodeController? _controller;
  bool _loading = true;
  String? _error;
  bool _dirty = false;
  bool _suppressDirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ap = context.read<AssetProvider>();
    final bytes = await ap.downloadAssetBytes(widget.assetId);
    if (!mounted) return;
    if (bytes == null) {
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить файл';
      });
      return;
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }
    final ctr = CodeController(text: text, language: lua);
    ctr.addListener(_onTextChanged);
    _suppressDirty = true;
    _controller = ctr;
    _suppressDirty = false;
    setState(() {
      _loading = false;
      _error = null;
    });
  }

  void _onTextChanged() {
    if (_suppressDirty || _loading) return;
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTextChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (widget.readOnly) return;
    final c = _controller;
    if (c == null) return;
    final ap = context.read<AssetProvider>();
    final err = await ap.putAssetContent(
      widget.projectId,
      widget.assetId,
      Uint8List.fromList(utf8.encode(c.fullText)),
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скрипт сохранён')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!widget.readOnly)
            TextButton.icon(
              onPressed: _loading ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text(
                        'Lua · Atom One Dark · Ctrl+S — сохранить'
                        '${widget.readOnly ? ' (только чтение)' : ''}',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.3),
                      ),
                    ),
                    if (_dirty && !widget.readOnly)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: Text(
                          'Есть несохранённые правки',
                          style: TextStyle(fontSize: 11, color: cs.tertiary),
                        ),
                      ),
                    Expanded(
                      child: Focus(
                        autofocus: true,
                        onKeyEvent: (node, event) {
                          if (widget.readOnly) return KeyEventResult.ignored;
                          if (event is! KeyDownEvent) return KeyEventResult.ignored;
                          final ctrl = HardwareKeyboard.instance.isControlPressed;
                          if (ctrl && event.logicalKey == LogicalKeyboardKey.keyS) {
                            _save();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: CodeTheme(
                          data: CodeThemeData(styles: atomOneDarkTheme),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
                              child: CodeField(
                                controller: _controller!,
                                readOnly: widget.readOnly,
                                gutterStyle: const GutterStyle(
                                  textStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                  showFoldingHandles: false,
                                  width: 44,
                                ),
                                textStyle: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13.5,
                                  height: 1.42,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
