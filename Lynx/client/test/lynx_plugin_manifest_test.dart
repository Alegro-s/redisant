import 'package:client/features/plugins/builtin/lynx_3d_plugin.dart';
import 'package:client/features/plugins/lynx_plugin_contract.dart';
import 'package:client/features/plugins/lynx_plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LynxProjectPlugins round-trip', () {
    const p = LynxProjectPlugins(
      enabled: [Lynx3dPluginIds.pluginId],
      config: {
        Lynx3dPluginIds.pluginId: {'defaultCamera': 'perspective'},
      },
    );
    final back = LynxProjectPlugins.fromJson(p.toJson());
    expect(back.enabled, [Lynx3dPluginIds.pluginId]);
    expect(back.is3dEnabled, isTrue);
  });

  test('3D plugin contributes scene extension', () {
    final plugin = Lynx3dClientPlugin();
    final ctx = LynxPluginProjectContext(
      projectRoot: '/tmp/demo',
      projectMode: LynxProjectMode.d3,
      plugins: LynxProjectPlugins(enabled: [Lynx3dPluginIds.pluginId]),
    );
    final c = plugin.contributeSceneExport(
      editorSceneJson: const {},
      ctx: ctx,
    );
    expect(c.enabledPluginIds, contains(Lynx3dPluginIds.pluginId));
    final block = c.extensions[Lynx3dPluginIds.sceneExtensionKey];
    expect(block, isA<Map>());
    expect((block as Map)['active'], isTrue);
  });
}
