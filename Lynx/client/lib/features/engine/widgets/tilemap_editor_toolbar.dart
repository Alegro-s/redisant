import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';
import '../runtime/tilemap_grid.dart';

class TilemapEditorToolbar extends StatelessWidget {
  const TilemapEditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SceneProvider, ProjectManager>(
      builder: (context, sceneProvider, manager, _) {
        final scene = sceneProvider.currentScene;
        if (scene == null || scene.tilemaps.isEmpty) {
          return const SizedBox.shrink();
        }
        final li = sceneProvider.tileLayerIndex.clamp(0, scene.tilemaps.length - 1);
        final layer = scene.tilemaps[li];
        final tilesets = manager.projectSettings?.tilesets ?? const <ProjectTileset>[];
        final cs = Theme.of(context).colorScheme;

        return Material(
          elevation: 2,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.95),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Тайлы'),
                    selected: sceneProvider.tileEditMode,
                    onSelected: (v) => sceneProvider.setTileEditMode(v),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Collision'),
                    selected: sceneProvider.showTileCollisionPreview,
                    onSelected: sceneProvider.setShowTileCollisionPreview,
                  ),
                  const SizedBox(width: 8),
                  Text('Слой:', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: li,
                    items: [
                      for (var i = 0; i < scene.tilemaps.length; i++)
                        DropdownMenuItem(value: i, child: Text(scene.tilemaps[i].id)),
                    ],
                    onChanged: (v) {
                      if (v != null) sceneProvider.setTileLayerIndex(v);
                    },
                  ),
                  const SizedBox(width: 8),
                  Text('Кисть:', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(width: 4),
                  DropdownButton<int>(
                    value: sceneProvider.tileBrushCollision,
                    items: const [
                      DropdownMenuItem(value: TileCollision.empty, child: Text('Пусто')),
                      DropdownMenuItem(value: TileCollision.solid, child: Text('Solid')),
                      DropdownMenuItem(value: TileCollision.oneWay, child: Text('One-way')),
                      DropdownMenuItem(value: TileCollision.slope45R, child: Text('Склон ↗')),
                      DropdownMenuItem(value: TileCollision.slope45L, child: Text('Склон ↖')),
                    ],
                    onChanged: (v) {
                      if (v != null) sceneProvider.setTileBrushCollision(v);
                    },
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Автотайл', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                      Switch(
                        value: layer.autotile,
                        onChanged: sceneProvider.tileEditMode
                            ? (v) => sceneProvider.setCurrentLayerAutotile(v)
                            : null,
                      ),
                    ],
                  ),
                  if (!layer.autotile) ...[
                    const SizedBox(width: 8),
                    Text('tile id', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove),
                      onPressed: sceneProvider.tileEditMode
                          ? () => sceneProvider.setTileManualTileId(sceneProvider.tileManualTileId - 1)
                          : null,
                    ),
                    Text('${sceneProvider.tileManualTileId}', style: TextStyle(color: cs.onSurface)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add),
                      onPressed: sceneProvider.tileEditMode
                          ? () => sceneProvider.setTileManualTileId(sceneProvider.tileManualTileId + 1)
                          : null,
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text('Тайлсет', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(width: 4),
                  DropdownButton<String?>(
                    value: layer.tilesetId?.isEmpty ?? true ? null : layer.tilesetId,
                    hint: const Text('—'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('нет')),
                      for (final t in tilesets)
                        DropdownMenuItem(value: t.id, child: Text(t.id)),
                    ],
                    onChanged: sceneProvider.tileEditMode
                        ? (v) => sceneProvider.setCurrentLayerTilesetId(v)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
