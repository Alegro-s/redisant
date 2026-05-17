import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../project_manager.dart';
import '../providers/scene_provider.dart';
import 'project_tree.dart';

class ProjectExplorerPanel extends StatefulWidget {
  final void Function(ProjectNode) onNodeSelected;
  final bool Function(ProjectNode node)? nodeVisible;
  final bool readOnly;
  final Uint8List minimalPngBytes;

  const ProjectExplorerPanel({
    super.key,
    required this.onNodeSelected,
    this.nodeVisible,
    required this.readOnly,
    required this.minimalPngBytes,
  });

  @override
  State<ProjectExplorerPanel> createState() => _ProjectExplorerPanelState();
}

class _ProjectExplorerPanelState extends State<ProjectExplorerPanel> {
  final TextEditingController _search = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<String?> _prompt(
    BuildContext context, {
    required String title,
    required String label,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return (r != null && r.isNotEmpty) ? r : null;
  }

  Future<void> _newFolder(BuildContext context, ProjectManager m) async {
    final path = await _prompt(
      context,
      title: 'Новая папка',
      label: 'Путь под assets (например scripts/foo)',
      initial: '',
    );
    if (path == null || !context.mounted) return;
    final err = await m.createAssetFolder(path);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Папка: assets/${path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '')}')),
      );
    }
  }

  Future<void> _newScript(BuildContext context, ProjectManager m) async {
    final name = await _prompt(
      context,
      title: 'Новый Lua-скрипт',
      label: 'Имя (без .lua)',
      initial: 'script_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (name == null || !context.mounted) return;
    final sub = await _prompt(
      context,
      title: 'Подпапка',
      label: 'Необязательно, под assets/scripts (например tetris)',
      initial: '',
    );
    if (!context.mounted) return;
    final segs = (sub == null || sub.isEmpty)
        ? <String>[]
        : sub.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).toList();
    final asset = await m.createScript(
      name,
      '-- NEXUS Lua\nreturn\n',
      pathSegments: segs,
    );
    if (!context.mounted) return;
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать скрипт')),
      );
      return;
    }
    if (m.canPushCloudAsset) {
      await m.ensureCloudIdForLocalAsset(asset.id);
    }
    if (!context.mounted) return;
    widget.onNodeSelected(
      ProjectNode(id: asset.id, name: asset.name, type: asset.type, path: asset.path),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Создан ${asset.path}')),
    );
  }

  Future<void> _newSprite(BuildContext context, ProjectManager m) async {
    final name = await _prompt(
      context,
      title: 'Новый спрайт PNG',
      label: 'Имя (без .png)',
      initial: 'sprite_${DateTime.now().millisecondsSinceEpoch}',
    );
    if (name == null || !context.mounted) return;
    final sub = await _prompt(
      context,
      title: 'Подпапка',
      label: 'Необязательно, под assets/sprites',
      initial: '',
    );
    if (!context.mounted) return;
    final segs = (sub == null || sub.isEmpty)
        ? <String>[]
        : sub.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).toList();
    final asset = await m.createSprite(
      name,
      widget.minimalPngBytes,
      pathSegments: segs,
    );
    if (!context.mounted) return;
    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать спрайт')),
      );
      return;
    }
    if (m.canPushCloudAsset) {
      await m.ensureCloudIdForLocalAsset(asset.id);
    }
    if (!context.mounted) return;
    widget.onNodeSelected(
      ProjectNode(id: asset.id, name: asset.name, type: asset.type, path: asset.path),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Создан ${asset.path}')),
    );
  }

  Future<void> _newScene(BuildContext context, ProjectManager m) async {
    final name = await _prompt(
      context,
      title: 'Новая сцена',
      label: 'Отображаемое имя',
      initial: 'Scene ${m.scenes.length + 1}',
    );
    if (name == null || !context.mounted) return;
    final scene = await m.createScene(name);
    if (!context.mounted) return;
    final sp = Provider.of<SceneProvider>(context, listen: false);
    sp.setCurrentScene(scene);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Сцена «${scene.name}»')),
    );
  }

  List<PopupMenuEntry<String>> _menuEntries(bool readOnly) {
    if (readOnly) {
      return [
        const PopupMenuItem(value: 'refresh', child: Text('Обновить')),
      ];
    }
    return [
      const PopupMenuItem(value: 'folder', child: Text('Новая папка')),
      const PopupMenuItem(value: 'script', child: Text('Новый Lua скрипт')),
      const PopupMenuItem(value: 'sprite', child: Text('Новый спрайт (1×1 PNG)')),
      const PopupMenuItem(value: 'scene', child: Text('Новая сцена')),
      const PopupMenuItem(value: 'refresh', child: Text('Обновить')),
    ];
  }

  Future<void> _onMenu(BuildContext context, ProjectManager m, String v) async {
    switch (v) {
      case 'folder':
        await _newFolder(context, m);
        break;
      case 'script':
        await _newScript(context, m);
        break;
      case 'sprite':
        await _newSprite(context, m);
        break;
      case 'scene':
        await _newScene(context, m);
        break;
      case 'refresh':
        await m.refreshAssetTree();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 520;

    return Consumer<ProjectManager>(
      builder: (context, manager, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  Text(
                    'ПРОВОДНИК',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.6,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _filter = v),
                      style: TextStyle(fontSize: 13, color: cs.onSurface),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Поиск…',
                        hintStyle: TextStyle(color: cs.outline),
                        prefixIcon: narrow
                            ? null
                            : Icon(Icons.search, size: 18, color: cs.outline),
                        suffixIcon: narrow
                            ? Icon(Icons.search, size: 18, color: cs.outline)
                            : null,
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: narrow ? 'Меню' : 'Создать',
                    icon: Icon(
                      narrow ? Icons.more_vert : Icons.add,
                      color: narrow ? cs.onSurfaceVariant : cs.primary,
                    ),
                    onSelected: (v) => _onMenu(context, manager, v),
                    itemBuilder: (_) => _menuEntries(widget.readOnly),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: cs.outline.withValues(alpha: 0.25)),
            Expanded(
              child: ColoredBox(
                color: cs.surfaceContainerHigh.withValues(alpha: 0.4),
                child: ProjectTree(
                  onNodeSelected: widget.onNodeSelected,
                  nodeVisible: widget.nodeVisible,
                  filter: _filter.isEmpty ? null : _filter,
                  onContextMenu: (node) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              title: Text(node.name, maxLines: 2),
                              subtitle: Text(
                                node.path.isEmpty ? '(корень)' : node.path,
                                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
