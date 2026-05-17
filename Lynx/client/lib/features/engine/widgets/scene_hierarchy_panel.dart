import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/engine_models.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';

class SceneHierarchyPanel extends StatelessWidget {
  const SceneHierarchyPanel({super.key});

  String? _displayNameForCollab(AuthProvider auth) {
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

  bool _isRoot(Scene scene, SceneObject o) {
    final pid = o.parentId;
    if (pid == null) return true;
    return !scene.objects.any((x) => x.id == pid);
  }

  bool _hasChildren(Scene scene, SceneObject o) =>
      scene.objects.any((x) => x.parentId == o.id);

  Future<void> _showObjectContextMenu(
    BuildContext context,
    Scene scene,
    SceneProvider sp,
    ProjectManager mgr,
    SceneObject o,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('Сохранить как префаб'),
              subtitle: const Text('Объект и дочерние в поддереве'),
              onTap: () => Navigator.pop(ctx, 'prefab'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
              title: Text('Удалить', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'delete') {
      sp.removeObject(o.id);
      mgr.scheduleSceneSave();
      return;
    }
    if (choice != 'prefab') return;
    final ctrl = TextEditingController(text: o.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Имя префаба'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Отображаемое имя'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    final name = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;
    final def = await mgr.savePrefabFromHierarchy(prefabName: name, scene: scene, root: o);
    if (!context.mounted) return;
    if (def != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Префаб сохранён: prefabs/${def.id}.json')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить префаб')),
      );
    }
  }

  List<Widget> _nodesForParent(
    BuildContext context,
    Scene scene,
    SceneProvider sp,
    ProjectManager mgr,
    String? parentId,
    int depth,
  ) {
    final cs = Theme.of(context).colorScheme;
    final children = scene.objects
        .where((o) {
          if (parentId == null) return _isRoot(scene, o);
          return o.parentId == parentId;
        })
        .toList()
      ..sort((a, b) {
        final z = a.z.compareTo(b.z);
        if (z != 0) return z;
        return a.name.compareTo(b.name);
      });

    final out = <Widget>[];
    for (final o in children) {
      final sel = sp.selectedObjectId == o.id;
      final hasKids = _hasChildren(scene, o);
      final collapsed = hasKids && mgr.isHierarchyNodeCollapsed(scene.id, o.id);
      Widget? expandBtn;
      if (hasKids) {
        expandBtn = InkWell(
          onTap: () {
            final auth = context.read<AuthProvider>();
            mgr.toggleHierarchyNodeCollapsed(
              scene.id,
              o.id,
              displayName: _displayNameForCollab(auth),
              cursorX: sp.lastEditorPointerLocal?.dx,
              cursorY: sp.lastEditorPointerLocal?.dy,
              selectedObjectId: sp.selectedObjectId,
            );
          },
          child: SizedBox(
            width: 28,
            height: 36,
            child: Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ),
        );
      } else {
        expandBtn = const SizedBox(width: 28, height: 36);
      }

      out.add(
        Material(
          color: sel ? cs.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
          child: InkWell(
            onTap: () => sp.selectObject(o.id),
            onLongPress: mgr.isCloudReadOnly
                ? null
                : () => _showObjectContextMenu(context, scene, sp, mgr, o),
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.only(left: 4.0 + depth * 12.0, right: 6),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  expandBtn,
                  Icon(
                    o.visible ? Icons.layers_outlined : Icons.layers_clear_outlined,
                    size: 18,
                  ),
                ],
              ),
              title: Text(
                o.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              subtitle: Text(
                o.assetId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10),
              ),
              selected: sel,
            ),
          ),
        ),
      );
      if (hasKids && !collapsed) {
        out.addAll(_nodesForParent(context, scene, sp, mgr, o.id, depth + 1));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer2<SceneProvider, ProjectManager>(
      builder: (context, sp, mgr, _) {
        final scene = sp.currentScene;
        if (scene == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(
                children: [
                  Icon(Icons.account_tree_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Hierarchy',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  if (mgr.hasActiveSceneCollab)
                    Tooltip(
                      message: 'Совместное редактирование: курсоры и раскрытие веток синхронизируются',
                      child: Icon(Icons.circle, size: 10, color: Colors.greenAccent.shade400),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _nodesForParent(context, scene, sp, mgr, null, 0),
              ),
            ),
          ],
        );
      },
    );
  }
}
