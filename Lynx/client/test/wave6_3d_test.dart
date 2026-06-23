import 'dart:convert';
import 'dart:io';

import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/lynx_windows_3d_runtime.dart';
import 'package:client/features/plugins/builtin/lynx_3d_plugin.dart';
import 'package:client/features/plugins/lynx_3d/lynx_3d_codec.dart';
import 'package:client/features/plugins/lynx_3d/lynx_glb_mesh.dart';
import 'package:client/features/plugins/lynx_plugin_contract.dart';
import 'package:client/features/plugins/lynx_plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('3d room demo enables lynx.3d and room extension', () async {
    final root = p.join(
      Directory.current.path,
      '..',
      'projects',
      'platformer-demo-3d-room',
    );
    final pj = File(p.join(root, 'project.json'));
    expect(await pj.exists(), isTrue);
    final gp = GameProject.fromJson(
      jsonDecode(await pj.readAsString()) as Map<String, dynamic>,
    );
    expect(gp.lynxPlugins.enabled, contains(Lynx3dPluginIds.pluginId));

    final scene = Scene.fromJson(
      jsonDecode(
        await File(p.join(root, 'scenes', 'main.json')).readAsString(),
      ) as Map<String, dynamic>,
    );
    final ext = Lynx3dSceneExtension.fromMap(
      scene.extensions[Lynx3dPluginIds.sceneExtensionKey] as Map<String, dynamic>?,
    );
    expect(ext, isNotNull);
    expect(ext!.room, isNotNull);
    expect(ext.objects, isNotEmpty);
    expect(gp.windows3dRuntime, LynxWindows3dRuntime.coreForwardD3d12);
    final crate = ext.objects.firstWhere((o) => o.id == 'crate_3d');
    expect(crate.physics.isStatic, isFalse);
    expect(crate.material.roughness, closeTo(0.7, 0.001));
  });

  test('Lynx3dClientPlugin export collects objects', () {
    final plugin = Lynx3dClientPlugin();
    final ctx = LynxPluginProjectContext(
      projectRoot: null,
      projectMode: LynxProjectMode.d3,
      plugins: const LynxProjectPlugins(
        apiVersion: 1,
        enabled: [Lynx3dPluginIds.pluginId],
      ),
    );
    final out = plugin.contributeSceneExport(
      editorSceneJson: {
        'objects': [
          {
            'id': 'box',
            'properties': {
              'lynx.3d': {
                'transform': {'position': [1, 2, 3]},
              },
            },
          },
        ],
      },
      ctx: ctx,
    );
    final block = out.extensions[Lynx3dPluginIds.sceneExtensionKey] as Map;
    expect(block['objects'], isA<List>());
    expect((block['objects'] as List).length, 1);
    expect(block['room'], isNotNull);
  });

  test('play bootstrap includes lynx3d for 3d room', () async {
    final root = p.normalize(
      p.join(Directory.current.path, '..', 'projects', 'platformer-demo-3d-room'),
    );
    final gp = GameProject.fromJson(
      jsonDecode(await File(p.join(root, 'project.json')).readAsString())
          as Map<String, dynamic>,
    );
    final scene = Scene.fromJson(
      jsonDecode(
        await File(p.join(root, 'scenes', 'main.json')).readAsString(),
      ) as Map<String, dynamic>,
    );
    final l3 = lynx3dPlayBootstrapFromScene(
      scene,
      windows3dRuntime: gp.windows3dRuntime,
      projectMode: gp.projectMode,
      plugin3dEnabled: gp.lynxPlugins.is3dEnabled,
    );
    expect(l3, isNotNull);
    final boot = l3!;
    expect(boot['room'], isNotNull);
    expect(boot['objects'], isA<List>());
    expect(boot['simulatePhysics'], isTrue);
    expect(boot['windows3dRuntime'], 'core_forward_d3d12');
    final bootExt = Lynx3dSceneExtension.fromMap(boot);
    expect(bootExt, isNotNull);
    final crate = bootExt!.objects.firstWhere((o) => o.id == 'crate_3d');
    expect(crate.physics.isStatic, isFalse);
  });

  test('crate.glb loads mesh with triangles', () async {
    final glb = p.join(
      Directory.current.path,
      '..',
      'projects',
      'platformer-demo-3d-room',
      'assets',
      'models',
      'crate.glb',
    );
    if (!File(glb).existsSync()) return;
    final mesh = await LynxGlbMesh.loadFile(glb);
    expect(mesh, isNotNull);
    expect(mesh!.triangleCount, greaterThan(0));
  });

  test('unit cube mesh has 12 triangles', () {
    expect(LynxGlbMesh.unitCube().triangleCount, 12);
  });

  test('codec roundtrip', () {
    final ext = Lynx3dSceneExtension(
      active: true,
      gravity: [0, -9.81, 0],
      ambientColor: '#404050',
      camera: const Lynx3dCameraSettings(orbitDistance: 10),
      room: const Lynx3dRoom(),
      objects: [
        Lynx3dObjectSpec(id: 'a', position: [0, 1, 0]),
      ],
    );
    final back = Lynx3dSceneExtension.fromMap(ext.toMap());
    expect(back?.objects.length, 1);
    expect(back?.camera.orbitDistance, 10);
  });
}
