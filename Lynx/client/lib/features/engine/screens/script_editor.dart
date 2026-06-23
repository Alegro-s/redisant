
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/lua.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../collab/script_studio_presence.dart';
import '../runtime/lynx_blueprint_service.dart';
import '../project_manager.dart';

class ScriptEditor extends StatefulWidget {
  final String assetId;

  const ScriptEditor({super.key, required this.assetId});

  @override
  State<ScriptEditor> createState() => _ScriptEditorState();
}

class _OutlineEntry {
  const _OutlineEntry({required this.label, required this.line});
  final String label;
  final int line;
}

class _ScriptEditorState extends State<ScriptEditor> {
  ProjectManager? _mgr;
  CodeController? _controller;
  final TextEditingController _findController = TextEditingController();
  String? _originalContent;
  bool _loading = true;
  bool _dirty = false;
  bool _suppressDirty = false;
  int _lastAppliedStudioRev = 0;
  DateTime _lastPresenceSent = DateTime.fromMillisecondsSinceEpoch(0);

  String? _collabDisplayName(AuthProvider auth) {
    final u = auth.user;
    if (u == null) return null;
    final nick = u.nickname.trim();
    if (nick.isNotEmpty) return nick;
    final full = u.fullName.trim();
    if (full.isNotEmpty) return full;
    final em = u.email.trim();
    if (em.contains('@')) return em.split('@').first;
    return em.isNotEmpty ? em : null;
  }

  void _emitStudioPresence() {
    final cid = _mgr?.cloudAssetIdForProjectAssetId(widget.assetId);
    if (cid == null || cid.isEmpty || _mgr == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final c = _controller;
    if (c == null) return;
    final now = DateTime.now();
    if (now.difference(_lastPresenceSent).inMilliseconds < 200) return;
    _lastPresenceSent = now;
    final text = c.fullText;
    final off = c.selection.baseOffset.clamp(0, text.length);
    var line = 1;
    var lineStart = 0;
    for (var i = 0; i < off; i++) {
      if (text[i] == '\n') {
        line++;
        lineStart = i + 1;
      }
    }
    final col = off - lineStart;
    _mgr!.sendStudioScriptPresence(
      cloudAssetId: cid,
      line: line,
      column: col,
      displayName: _collabDisplayName(auth),
    );
  }

  void _onTextChanged() {
    if (_suppressDirty) return;
    if (!mounted) return;
    setState(() => _dirty = true);
    _emitStudioPresence();
  }

  void _onProjectManagerNotify() {
    if (!mounted || _loading || _mgr == null) return;
    setState(() {});
    unawaited(_applyRemoteIfNeeded(_mgr!));
  }

  @override
  void initState() {
    super.initState();
    _mgr = context.read<ProjectManager>();
    _mgr!.addListener(_onProjectManagerNotify);
    _loadScript();
  }

  Future<void> _loadScript() async {
    final manager = _mgr!;
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    final file = File('${manager.rootPath}/${asset.path}');
    String content = '';
    if (await file.exists()) {
      content = await file.readAsString();
    }
    _originalContent = content;
    final ctr = CodeController(
      text: content,
      language: lua,
    );
    ctr.addListener(_onTextChanged);
    _controller = ctr;
    _lastAppliedStudioRev =
        manager.studioAssetRefreshRevision(manager.cloudAssetIdForProjectAssetId(widget.assetId));
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _applyRemoteIfNeeded(ProjectManager manager) async {
    final cid = manager.cloudAssetIdForProjectAssetId(widget.assetId);
    if (cid == null || _loading) return;
    final rev = manager.studioAssetRefreshRevision(cid);
    if (rev == _lastAppliedStudioRev) return;
    if (_dirty) return;
    final filePath =
        '${manager.rootPath}/${manager.assets.firstWhere((a) => a.id == widget.assetId).path}';
    final file = File(filePath);
    if (!await file.exists()) return;
    final text = await file.readAsString();
    final c = _controller;
    if (c == null || !mounted) return;
    if (text == c.fullText) {
      _lastAppliedStudioRev = rev;
      return;
    }
    _suppressDirty = true;
    c.removeListener(_onTextChanged);
    c.dispose();
    final ctr = CodeController(text: text, language: lua);
    ctr.addListener(_onTextChanged);
    _controller = ctr;
    _originalContent = text;
    _suppressDirty = false;
    _lastAppliedStudioRev = rev;
    _dirty = false;
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Скрипт обновлён от напарника (облако)')),
      );
    }
  }

  Future<void> _saveScript() async {
    final c = _controller;
    if (c == null || _mgr == null) return;
    final text = c.fullText;
    if (text == _originalContent) return;
    final manager = _mgr!;
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    final file = File('${manager.rootPath}/${asset.path}');
    await file.writeAsString(text);
    _originalContent = text;
    _dirty = false;
    final bytes = Uint8List.fromList(utf8.encode(text));
    var cloudOk = false;
    if (manager.canPushCloudAsset) {
      cloudOk = await manager.syncLocalAssetBytesToCloud(widget.assetId, bytes);
    }
    if (mounted) {
      final cid = manager.cloudAssetIdForProjectAssetId(widget.assetId);
      _lastAppliedStudioRev = manager.studioAssetRefreshRevision(cid);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cloudOk
                ? 'Скрипт сохранён и отправлен в облако'
                : (manager.canPushCloudAsset
                    ? 'Сохранено локально; синхронизация с сервером не удалась'
                    : 'Скрипт сохранён в assets'),
          ),
        ),
      );
      setState(() {});
    }
  }

  List<_OutlineEntry> _luaOutlineHeuristic(String text) {
    final lines = text.split('\n');
    final out = <_OutlineEntry>[];
    final reFn = RegExp(r'^\s*function\s+([a-zA-Z_][\w]*)\s*\(');
    final reLocalFn = RegExp(r'^\s*local\s+function\s+([a-zA-Z_][\w]*)');
    final reComment = RegExp(r'^\s*--+\s*(.+)\s*$');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      var m = reFn.firstMatch(line);
      if (m != null) {
        out.add(_OutlineEntry(label: 'ƒ ${m.group(1)}', line: i + 1));
        continue;
      }
      m = reLocalFn.firstMatch(line);
      if (m != null) {
        out.add(_OutlineEntry(label: 'ƒ ${m.group(1)} (local)', line: i + 1));
        continue;
      }
      m = reComment.firstMatch(line);
      if (m != null) {
        var t = m.group(1)!.trim();
        if (t.length > 2) {
          if (t.length > 42) t = '${t.substring(0, 40)}…';
          out.add(_OutlineEntry(label: t, line: i + 1));
        }
      }
    }
    return out;
  }

  void _jumpToLine(int line1) {
    final c = _controller;
    if (c == null) return;
    final lines = c.fullText.split('\n');
    if (line1 < 1 || line1 > lines.length) return;
    var off = 0;
    for (var i = 0; i < line1 - 1; i++) {
      off += lines[i].length + 1;
    }
    c.selection = TextSelection.collapsed(offset: off.clamp(0, c.fullText.length));
    if (mounted) setState(() {});
  }

  void _findNext() {
    final c = _controller;
    if (c == null) return;
    final q = _findController.text;
    if (q.isEmpty) return;
    final text = c.fullText;
    final start = c.selection.baseOffset;
    var idx = text.indexOf(q, start >= 0 && start < text.length ? start + 1 : 0);
    if (idx < 0) idx = text.indexOf(q);
    if (idx >= 0) {
      c.selection = TextSelection(baseOffset: idx, extentOffset: idx + q.length);
      if (mounted) setState(() {});
    }
  }

  void _findPrev() {
    final c = _controller;
    if (c == null) return;
    final q = _findController.text;
    if (q.isEmpty) return;
    final text = c.fullText;
    final from = c.selection.start;
    var idx = from > 0 ? text.lastIndexOf(q, from - 1) : -1;
    if (idx < 0) idx = text.lastIndexOf(q);
    if (idx >= 0) {
      c.selection = TextSelection(baseOffset: idx, extentOffset: idx + q.length);
      if (mounted) setState(() {});
    }
  }

  Future<void> _reloadFromDisk() async {
    final manager = _mgr!;
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    final file = File('${manager.rootPath}/${asset.path}');
    if (!await file.exists()) return;
    final content = await file.readAsString();
    final c = _controller;
    if (c == null || !mounted) return;
    _suppressDirty = true;
    c.removeListener(_onTextChanged);
    c.dispose();
    final ctr = CodeController(text: content, language: lua);
    ctr.addListener(_onTextChanged);
    _controller = ctr;
    _originalContent = content;
    _suppressDirty = false;
    _dirty = false;
    if (mounted) setState(() {});
  }

  Future<void> _openBlueprint() async {
    final manager = _mgr!;
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    await openBlueprintEditorForScript(
      context,
      manager,
      asset,
      onSaved: _reloadFromDisk,
    );
  }

  @override
  void dispose() {
    _findController.dispose();
    _mgr?.removeListener(_onProjectManagerNotify);
    _controller?.removeListener(_onTextChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final manager = _mgr!;
    final cid = manager.cloudAssetIdForProjectAssetId(widget.assetId);
    final now = DateTime.now();
    var remotes = <String, ScriptStudioRemote>{};
    if (cid != null) {
      remotes = Map<String, ScriptStudioRemote>.from(manager.scriptStudioRemotesForCloudAsset(cid));
      remotes.removeWhere(
        (_, v) => now.difference(v.updatedAt).inSeconds > 45,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            children: [
              Icon(Icons.code, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cid != null
                      ? 'Lua · live-коллаб по облаку · Ctrl+S — сохранить и синхронизировать'
                      : 'Lua · поиск/замена в поле · Tab · Ctrl+/ комментарий · Atom One Dark',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        if (remotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: remotes.values.map((r) {
                return Chip(
                  avatar: CircleAvatar(
                    radius: 10,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      r.label.isNotEmpty ? r.label[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  label: Text('${r.label} · стр. ${r.line}', style: const TextStyle(fontSize: 11)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _findController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Найти в файле',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (_) => _findNext(),
                ),
              ),
              IconButton(
                tooltip: 'Следующее вхождение',
                onPressed: _findNext,
                icon: const Icon(Icons.keyboard_arrow_down, size: 22),
              ),
              IconButton(
                tooltip: 'Предыдущее вхождение',
                onPressed: _findPrev,
                icon: const Icon(Icons.keyboard_arrow_up, size: 22),
              ),
            ],
          ),
        ),
        Expanded(
          child: Focus(
            autofocus: false,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              final isCtrl = HardwareKeyboard.instance.isControlPressed;
              if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
                _saveScript();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final outline = _luaOutlineHeuristic(_controller!.fullText);
                final outlinePanel = Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 8, 4),
                        child: Text(
                          'Структура',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      Expanded(
                        child: outline.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    'Нет совпадений (function / local function / --)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: outline.length,
                                itemBuilder: (ctx, i) {
                                  final e = outline[i];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(
                                      e.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                    subtitle: Text(
                                      'стр. ${e.line}',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                    onTap: () => _jumpToLine(e.line),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
                final editor = CodeTheme(
                  data: CodeThemeData(styles: atomOneDarkTheme),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 12, 16),
                      child: CodeField(
                        key: ValueKey('${widget.assetId}_$_lastAppliedStudioRev${cid ?? ''}'),
                        controller: _controller!,
                        gutterStyle: const GutterStyle(
                          textStyle: TextStyle(color: Colors.grey, fontSize: 12),
                          showFoldingHandles: false,
                          width: 48,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13.5,
                          height: 1.42,
                        ),
                      ),
                    ),
                  ),
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 120, child: outlinePanel),
                      const Divider(height: 1),
                      Expanded(child: editor),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: editor),
                    const VerticalDivider(width: 1),
                    SizedBox(width: 200, child: outlinePanel),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _saveScript,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(
                  cid != null ? 'Сохранить и в облако' : 'Сохранить в assets',
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: manager.isCloudReadOnly ? null : _openBlueprint,
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: const Text('Blueprint'),
              ),
              if (_dirty) ...[
                const SizedBox(width: 12),
                Text(
                  'Локальные правки не перезаписываются с сервера',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
