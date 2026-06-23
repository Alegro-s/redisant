import '../lynx_plugin_registry.dart';
import 'lynx_3d_plugin.dart';

void registerBuiltinPlugins(LynxPluginRegistry registry) {
  registry.registerBuiltin(Lynx3dClientPlugin());
}
