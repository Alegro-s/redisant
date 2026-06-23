import 'dart:convert';
import 'dart:io';

import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/scene_to_engine_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final demoRoot = p.normalize(
    p.join(Directory.current.path, '..', 'projects', 'platformer-demo'),
  );

  test('platformer-demo assets exist', () async {
    expect(
      File(p.join(demoRoot, 'assets', 'tilesets', 'platform.png')).existsSync(),
      isTrue,
      reason: 'Run: python Lynx/scripts/generate_wave0_demo_assets.py',
    );
    expect(
      File(p.join(demoRoot, 'assets', 'sprites', 'hero.png')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(demoRoot, 'scenes', 'main.json')).existsSync(),
      isTrue,
    );
  });

  test('export includes tilemaps, animator, and tileset in project', () async {
    final projectJson =
        jsonDecode(await File(p.join(demoRoot, 'project.json')).readAsString())
            as Map<String, dynamic>;
    final project = GameProject.fromJson(projectJson);
    expect(project.tilesets, isNotEmpty);
    expect(project.tilesets.first.id, 'platform');

    final sceneJson =
        jsonDecode(await File(p.join(demoRoot, 'scenes', 'main.json')).readAsString())
            as Map<String, dynamic>;
    final scene = Scene.fromJson(sceneJson);
    expect(scene.tilemaps, isNotEmpty);
    expect(scene.objects.any((o) => o.name == 'Player'), isTrue);

    final assets = <ProjectAsset>[];
    final assetsDir = Directory(p.join(demoRoot, 'assets'));
    await for (final f in assetsDir.list(recursive: true)) {
      if (f is! File) continue;
      if (!f.path.endsWith('.png') && !f.path.endsWith('.lua')) continue;
      final rel = p.relative(f.path, from: demoRoot).replaceAll('\\', '/');
      final type = rel.endsWith('.lua') ? 'script' : 'sprite';
      SpriteAssetMeta? meta;
      if (type == 'sprite') {
        final metaPath = p.join(
          p.dirname(f.path),
          '${p.basenameWithoutExtension(f.path)}.meta.json',
        );
        final metaFile = File(metaPath);
        if (await metaFile.exists()) {
          meta = SpriteAssetMeta.fromJson(
            jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>,
          );
        }
      }
      assets.add(
        ProjectAsset(
          id: rel.replaceAll('/', '_'),
          name: p.basename(rel),
          type: type,
          path: rel,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
          spriteMeta: meta,
        ),
      );
    }

    final rustJson = await buildEngineRuntimeSceneJson(
      scene: scene,
      projectRoot: demoRoot,
      assets: assets,
      project: project,
    );
    final map = jsonDecode(rustJson) as Map<String, dynamic>;
    final tilemaps = map['tilemaps'] as List?;
    expect(tilemaps, isNotEmpty);

    final entities = map['entities'] as List;
    final player = entities.cast<Map>().firstWhere(
          (e) => (e['name'] as String?) == 'Player',
        );
    final sprite = player['sprite'] as Map<String, dynamic>;
    expect(sprite['animation'], isNotNull);
    expect(player['animator'], isNotNull);
    expect(player['platformer_motor'], isNotNull);
    expect(player['script'], isNotNull);
  });
}
