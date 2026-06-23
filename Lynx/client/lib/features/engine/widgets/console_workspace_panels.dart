import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../plugins/lynx_plugin_manifest.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';
import '../runtime/tic_grid_codec.dart';
import '../screens/script_editor.dart';
import '../screens/sprite_editor.dart';
import '../widgets/embedded_game_preview.dart';
import '../widgets/engine_scene_viewport_controller.dart';
import '../widgets/scene_editor.dart';
import '../widgets/sound_asset_panel.dart';
import '../widgets/tic_console_map_editor.dart';
import '../widgets/tic_console_music_editor.dart';
import '../widgets/tic_console_sfx_editor.dart';
import '../widgets/tic_console_sprite_editor.dart';

/// E17b + TIC API layer — compact editors для `projectMode: tic`.
class ConsoleWorkspacePanels extends StatelessWidget {
  const ConsoleWorkspacePanels({
    super.key,
    required this.tab,
    required this.projectRoot,
    this.viewportController,
    this.onConsoleLine,
    this.previewActive = true,
  });

  final int tab;
  final String? projectRoot;
  final EngineSceneViewportController? viewportController;
  final void Function(String line)? onConsoleLine;
  final bool previewActive;

  bool _isTicMode(ProjectManager manager) {
    final mode = manager.projectSettings?.projectMode ?? LynxProjectMode.d2;
    final tpl = manager.projectSettings?.gameTemplate ?? '';
    return mode == LynxProjectMode.tic || projectUsesTicApi(gameTemplate: tpl, projectMode: mode.jsonValue);
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ProjectManager>();
    final readOnly = manager.isCloudReadOnly;
    final path = projectRoot;
    final tic = _isTicMode(manager);

    if (tic && path != null && path.isNotEmpty) {
      ensureTicProjectAssets(path);
    }

    switch (tab) {
      case 0:
        return _assetPanel(
          context,
          manager: manager,
          readOnly: readOnly,
          type: 'script',
          emptyHint: tic
              ? 'Создайте assets/scripts/game.lua — TIC API: spr(), map(), btn().'
              : 'Нет Lua-скриптов. Создайте assets/scripts/game.lua в проекте.',
          builder: (id) => ScriptEditor(assetId: id),
          preferNameContains: tic ? const ['game'] : const [],
        );
      case 1:
        if (tic && path != null && path.isNotEmpty) {
          return TicConsoleSpriteEditor(projectRoot: path);
        }
        return _assetPanel(
          context,
          manager: manager,
          readOnly: readOnly,
          type: 'sprite',
          emptyHint: 'Нет спрайтов. Импортируйте PNG или создайте спрайт в ассетах.',
          builder: (id) => SpriteEditor(assetId: id),
        );
      case 2:
        if (tic && path != null && path.isNotEmpty) {
          return TicConsoleMapEditor(projectRoot: path);
        }
        if (readOnly) {
          return const Center(child: Text('Режим просмотра: карта недоступна'));
        }
        return ChangeNotifierProvider<SceneProvider>.value(
          value: context.read<SceneProvider>(),
          child: SceneEditor(viewportController: viewportController),
        );
      case 3:
        if (tic && path != null && path.isNotEmpty) {
          return TicConsoleSfxEditor(projectRoot: path);
        }
        return _assetPanel(
          context,
          manager: manager,
          readOnly: readOnly,
          type: 'sound',
          emptyHint: 'Нет звуковых эффектов. Добавьте WAV/OGG в assets/sounds.',
          builder: (id) => SoundAssetPanel(assetId: id),
        );
      case 4:
        if (tic && path != null && path.isNotEmpty) {
          return TicConsoleMusicEditor(projectRoot: path);
        }
        return _assetPanel(
          context,
          manager: manager,
          readOnly: readOnly,
          type: 'sound',
          emptyHint: 'Музыка — те же звуковые ассеты. Добавьте трек в assets/sounds.',
          builder: (id) => SoundAssetPanel(assetId: id),
          preferNameContains: const ['music', 'bgm', 'track'],
        );
      case 5:
      default:
        if (path == null || path.isEmpty) {
          return const Center(child: Text('Откройте проект для Play'));
        }
        return EmbeddedGamePreview(
          projectPath: path,
          freshPlay: false,
          active: previewActive,
          onConsoleLine: onConsoleLine,
          forcePixelPerfect: true,
        );
    }
  }

  static Widget _assetPanel(
    BuildContext context, {
    required ProjectManager manager,
    required bool readOnly,
    required String type,
    required String emptyHint,
    required Widget Function(String assetId) builder,
    List<String> preferNameContains = const [],
  }) {
    if (readOnly && type != 'script') {
      return const Center(child: Text('Режим просмотра'));
    }
    final assets = manager.assets.where((a) => a.type == type).toList();
    if (assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyHint, textAlign: TextAlign.center),
        ),
      );
    }
    String? pickId;
    for (final hint in preferNameContains) {
      final hit = assets.where((a) => a.name.toLowerCase().contains(hint)).firstOrNull;
      if (hit != null) {
        pickId = hit.id;
        break;
      }
    }
    pickId ??= assets.first.id;
    return builder(pickId);
  }
}
