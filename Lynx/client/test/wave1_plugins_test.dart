import 'dart:convert';
import 'dart:io';

import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/scene_to_engine_json.dart';
import 'package:client/features/plugins/lynx_plugin_contract.dart';
import 'package:client/features/plugins/lynx_plugin_host.dart';
import 'package:client/features/plugins/lynx_plugin_manifest.dart';
import 'package:client/features/plugins/lynx_plugin_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() {
    LynxPluginRegistry.instance.ensureInitialized();
  });

  test('platformer-demo-3d project enables lynx.3d', () async {
    final root = p.normalize(
      p.join(Directory.current.path, '..', 'projects', 'platformer-demo-3d'),
    );
    final projFile = File(p.join(root, 'project.json'));
    expect(projFile.existsSync(), isTrue, reason: 'Run generate_wave0_demo_assets.py');

    final project = GameProject.fromJson(
      jsonDecode(await projFile.readAsString()) as Map<String, dynamic>,
    );
    expect(project.lynxPlugins.enabled, contains(Lynx3dPluginIds.pluginId));
    expect(project.projectMode, LynxProjectMode.d3);

    final scene = Scene.fromJson(
      jsonDecode(await File(p.join(root, 'scenes', 'main.json')).readAsString())
          as Map<String, dynamic>,
    );
    expect(scene.extensions.containsKey(Lynx3dPluginIds.sceneExtensionKey), isTrue);

    await LynxPluginHost.instance.openProject(
      LynxPluginProjectContext(
        projectRoot: root,
        projectMode: project.projectMode,
        plugins: project.lynxPlugins,
        displayName: project.displayName,
      ),
    );
    expect(LynxPluginHost.instance.is3dActive, isTrue);

    LynxPluginHost.instance.applySceneExtensions(scene);
    expect(scene.extensions[Lynx3dPluginIds.sceneExtensionKey], isNotNull);

    final merge = LynxPluginHost.instance.mergeSceneExport(scene.toJson());
    expect(merge.extensions[Lynx3dPluginIds.sceneExtensionKey], isNotNull);
    expect(merge.enabledPluginIds, contains(Lynx3dPluginIds.pluginId));

    await LynxPluginHost.instance.closeProject();
  });

  test('rust export carries extensions and enabled_plugins', () async {
    final root = p.normalize(
      p.join(Directory.current.path, '..', 'projects', 'platformer-demo-3d'),
    );
    final project = GameProject.fromJson(
      jsonDecode(await File(p.join(root, 'project.json')).readAsString())
          as Map<String, dynamic>,
    );
    final scene = Scene.fromJson(
      jsonDecode(await File(p.join(root, 'scenes', 'main.json')).readAsString())
          as Map<String, dynamic>,
    );
    await LynxPluginHost.instance.openProject(
      LynxPluginProjectContext(
        projectRoot: root,
        projectMode: project.projectMode,
        plugins: project.lynxPlugins,
      ),
    );

    final assets = <ProjectAsset>[];
    final assetsDir = Directory(p.join(root, 'assets'));
    await for (final f in assetsDir.list(recursive: true)) {
      if (f is! File) continue;
      if (!f.path.endsWith('.png') && !f.path.endsWith('.lua')) continue;
      final rel = p.relative(f.path, from: root).replaceAll('\\', '/');
      assets.add(
        ProjectAsset(
          id: rel.replaceAll('/', '_'),
          name: p.basename(rel),
          type: rel.endsWith('.lua') ? 'script' : 'sprite',
          path: rel,
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );
    }

    final rustJson = await buildEngineRuntimeSceneJson(
      scene: scene,
      projectRoot: root,
      assets: assets,
      project: project,
    );
    final map = jsonDecode(rustJson) as Map<String, dynamic>;
    expect(map['extensions'], isNotNull);
    final ext = map['extensions'] as Map<String, dynamic>;
    expect(ext[Lynx3dPluginIds.sceneExtensionKey], isNotNull);
    expect(map['enabled_plugins'], contains(Lynx3dPluginIds.pluginId));

    await LynxPluginHost.instance.closeProject();
  });
}
