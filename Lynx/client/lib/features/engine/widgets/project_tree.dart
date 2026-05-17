import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../project_manager.dart';

class ProjectTree extends StatelessWidget {
  final Function(ProjectNode) onNodeSelected;
  final bool Function(ProjectNode node)? nodeVisible;
  final ProjectNode? rootOverride;
  final String? filter;
  final void Function(ProjectNode node)? onContextMenu;

  const ProjectTree({
    super.key,
    required this.onNodeSelected,
    this.nodeVisible,
    this.rootOverride,
    this.filter,
    this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectManager>(
      builder: (context, manager, child) {
        final root = rootOverride ?? manager.treeRoot;
        if (root == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('Проект не загружен', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final q = (filter ?? '').trim().toLowerCase();

        bool nodeVisibleDeep(ProjectNode node) {
          if (nodeVisible == null) return true;
          if (node.type == 'folder') {
            if (node.children.isEmpty) return true;
            return node.children.any(nodeVisibleDeep);
          }
          return nodeVisible!(node);
        }

        bool subtreeMatches(ProjectNode node) {
          if (q.isEmpty) return true;
          if (node.name.toLowerCase().contains(q)) return true;
          return node.children.any(subtreeMatches);
        }

        final topChildren = root.children
            .where((n) => nodeVisibleDeep(n) && subtreeMatches(n))
            .toList();
        if (topChildren.isEmpty) {
          return Center(
            child: Text(
              q.isEmpty ? 'Нет элементов для текущего режима' : 'Ничего не найдено',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: topChildren.length,
          itemBuilder: (context, index) {
            return _buildNode(topChildren[index], depth: 0);
          },
        );
      },
    );
  }

  Widget _buildNode(ProjectNode node, {required int depth}) {
    if (node.type == 'folder') {
      return _FolderNode(
        node: node,
        depth: depth,
        onNodeSelected: onNodeSelected,
        nodeVisible: nodeVisible,
        filter: filter,
        onContextMenu: onContextMenu,
      );
    } else {
      return _FileNode(
        node: node,
        depth: depth,
        onTap: () => onNodeSelected(node),
        onContextMenu: onContextMenu,
      );
    }
  }
}

class _FolderNode extends StatefulWidget {
  final ProjectNode node;
  final int depth;
  final Function(ProjectNode) onNodeSelected;
  final bool Function(ProjectNode node)? nodeVisible;
  final String? filter;
  final void Function(ProjectNode node)? onContextMenu;

  const _FolderNode({
    required this.node,
    required this.depth,
    required this.onNodeSelected,
    required this.nodeVisible,
    required this.filter,
    required this.onContextMenu,
  });

  @override
  State<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends State<_FolderNode> {
  bool nodeVisibleDeep(ProjectNode node) {
    if (widget.nodeVisible == null) return true;
    if (node.type == 'folder') {
      if (node.children.isEmpty) return true;
      return node.children.any(nodeVisibleDeep);
    }
    return widget.nodeVisible!(node);
  }

  bool subtreeMatches(ProjectNode node) {
    final q = (widget.filter ?? '').trim().toLowerCase();
    if (q.isEmpty) return true;
    if (node.name.toLowerCase().contains(q)) return true;
    return node.children.any(subtreeMatches);
  }

  List<ProjectNode> _visibleChildren(ProjectNode folder) {
    return folder.children
        .where((c) => nodeVisibleDeep(c) && subtreeMatches(c))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleChildren = _visibleChildren(widget.node);
    final indent = 10.0 + widget.depth * 12.0;
    final cs = Theme.of(context).colorScheme;

    Widget row = ListTile(
      contentPadding: EdgeInsets.only(left: indent, right: 8),
      leading: Icon(
        visibleChildren.isEmpty ? Icons.folder_open_outlined : Icons.folder_outlined,
        size: 20,
        color: cs.primary.withValues(alpha: 0.85),
      ),
      title: Text(
        widget.node.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(
        visibleChildren.isEmpty
            ? Icons.remove
            : (widget.node.isExpanded ? Icons.expand_less : Icons.expand_more),
        size: 20,
      ),
      dense: true,
      onTap: () {
        setState(() {
          widget.node.isExpanded = !widget.node.isExpanded;
        });
      },
    );

    if (widget.onContextMenu != null) {
      row = GestureDetector(
        onLongPress: () => widget.onContextMenu!(widget.node),
        child: row,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (widget.node.isExpanded && visibleChildren.isNotEmpty)
          Column(
            children: visibleChildren
                .map(
                  (child) => _buildChildNode(child, widget.depth + 1),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildChildNode(ProjectNode node, int depth) {
    if (node.type == 'folder') {
      return _FolderNode(
        node: node,
        depth: depth,
        onNodeSelected: widget.onNodeSelected,
        nodeVisible: widget.nodeVisible,
        filter: widget.filter,
        onContextMenu: widget.onContextMenu,
      );
    } else {
      return _FileNode(
        node: node,
        depth: depth,
        onTap: () => widget.onNodeSelected(node),
        onContextMenu: widget.onContextMenu,
      );
    }
  }
}

class _FileNode extends StatelessWidget {
  final ProjectNode node;
  final int depth;
  final VoidCallback onTap;
  final void Function(ProjectNode node)? onContextMenu;

  const _FileNode({
    required this.node,
    required this.depth,
    required this.onTap,
    required this.onContextMenu,
  });

  IconData _getIcon() {
    switch (node.type) {
      case 'sprite':
        return Icons.image_outlined;
      case 'script':
        return Icons.code_outlined;
      case 'sound':
        return Icons.audiotrack;
      case 'scene':
        return Icons.movie_filter_outlined;
      case 'prefab':
        return Icons.widgets_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final indent = 10.0 + depth * 12.0;
    final cs = Theme.of(context).colorScheme;

    Widget tile = ListTile(
      contentPadding: EdgeInsets.only(left: indent, right: 8),
      leading: Icon(_getIcon(), size: 18, color: cs.secondary),
      title: Text(node.name, style: const TextStyle(fontSize: 12.5)),
      dense: true,
      onTap: onTap,
    );

    if (onContextMenu != null) {
      tile = GestureDetector(
        onLongPress: () => onContextMenu!(node),
        child: tile,
      );
    }

    if (node.type == 'sprite' || node.type == 'script') {
      return Draggable<String>(
        data: node.id,
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Opacity(
              opacity: 0.85,
              child: tile,
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.45, child: tile),
        child: tile,
      );
    }

    return tile;
  }
}
