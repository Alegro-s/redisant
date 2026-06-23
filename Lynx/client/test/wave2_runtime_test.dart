import 'dart:convert';
import 'dart:io';

import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/input_map_codec.dart';
import 'package:client/features/engine/runtime/scene_autoload_merge.dart';
import 'package:client/features/engine/runtime/scene_to_engine_json.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final wave2Root = p.normalize(
    p.join(Directory.current.path, '..', 'projects', 'platformer-wave2'),
  );

  test('platformer-wave2 project has menu startup and input map', () {
    final pj = File(p.join(wave2Root, 'project.json'));
    expect(pj.existsSync(), isTrue, reason: 'Run scripts/generate_wave0_demo_assets.py');
    final gp = GameProject.fromJson(
      jsonDecode(pj.readAsStringSync()) as Map<String, dynamic>,
    );
    expect(gp.startupSceneId, 'menu');
    expect(gp.autoloadSceneIds, contains('bootstrap'));
    expect(gp.inputMap['confirm'], isNotNull);
  });

  test('engine json includes input_map and scene_id', () async {
    final menuFile = File(p.join(wave2Root, 'scenes', 'menu.json'));
    expect(menuFile.existsSync(), isTrue);
    final scene = Scene.fromJson(
      jsonDecode(menuFile.readAsStringSync()) as Map<String, dynamic>,
    );
    final gp = GameProject.fromJson(
      jsonDecode(File(p.join(wave2Root, 'project.json')).readAsStringSync())
          as Map<String, dynamic>,
    );
    final merged = await mergeAutoloadIntoScene(
      projectRoot: wave2Root,
      mainScene: scene,
      mainSceneId: 'menu',
      autoloadSceneIds: gp.autoloadSceneIds,
    );
    expect(
      merged.objects.any((o) => o.id.startsWith('autoload_bootstrap_')),
      isTrue,
    );
    final raw = await buildEngineRuntimeSceneJson(
      scene: merged,
      projectRoot: wave2Root,
      assets: const [],
      project: gp,
      playSceneId: 'menu',
    );
    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['scene_id'], 'menu');
    final im = map['input_map'] as Map?;
    expect(im, isNotNull);
    expect(im!['confirm'], isA<List>());
    expect(normalizeInputMapForEngine(gp.inputMap)['jump'], contains('Space'));
  });
}
