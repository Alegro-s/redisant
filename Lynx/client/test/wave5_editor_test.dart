import 'dart:io';

import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/animation_player_codec.dart';
import 'package:client/features/engine/runtime/lynx_project_templates.dart';
import 'package:client/features/engine/runtime/scene_ui_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('animation preset from hero meta shape', () {
    final meta = SpriteAssetMeta(
      sheetAnimation: SpriteSheetAnimMeta(
        fps: 8,
        frames: const [
          SpriteAnimFrameMeta(x: 0, y: 0, w: 32, h: 32),
          SpriteAnimFrameMeta(x: 32, y: 0, w: 32, h: 32),
        ],
      ),
    );
    final preset = animationPresetFromSpriteMeta(meta);
    expect(preset, isNotNull);
    expect(preset!.clips.containsKey('idle'), isTrue);
    expect(preset.clips.containsKey('run'), isTrue);
  });

  test('ui widgets from scene layer', () {
    final scene = Scene(
      id: 'menu',
      name: 'Menu',
      objects: [
        SceneObject(
          id: 'btn',
          name: 'Start',
          assetId: '',
          x: 100,
          y: 200,
          layerId: SceneLayer.uiLayerId,
          properties: defaultUiButtonProperties('Go', 'load_scene:main'),
        ),
      ],
      createdAt: DateTime.now().toUtc(),
      modifiedAt: DateTime.now().toUtc(),
    );
    final ui = buildUiWidgetsFromScene(scene);
    expect(ui.length, 1);
    expect(ui.first['action'], 'load_scene:main');
  });

  test('empty template materializes v3 scene', () async {
    final tmp = await Directory.systemTemp.createTemp('lynx_tpl_');
    final repo = p.normalize(p.join(Directory.current.path, '..'));
    final err = await materializeLynxProjectTemplate(
      templateId: 'empty',
      destPath: p.join(tmp.path, 'empty_proj'),
      repoRoot: repo,
      displayName: 'Test Empty',
    );
    expect(err, isNull);
    expect(File(p.join(tmp.path, 'empty_proj', 'scenes', 'main.json')).existsSync(), isTrue);
    await tmp.delete(recursive: true);
  });
}
