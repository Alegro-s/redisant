import 'dart:io';

import 'package:args/args.dart';

Map<String, Object?> readEditorBootstrapRaw() => readEngineBootstrapRaw();

Map<String, Object?> readEngineBootstrapRaw() {
  const fromEnv = String.fromEnvironment('NEXUS_PROJECT_ID', defaultValue: '');
  const nameEnv = String.fromEnvironment('NEXUS_PROJECT_NAME', defaultValue: '');
  const apiEnv = String.fromEnvironment('NEXUS_API_BASE', defaultValue: '');
  const roEnv = bool.fromEnvironment('NEXUS_CLOUD_READONLY', defaultValue: false);
  const engineVerEnv = String.fromEnvironment('LYNX_ENGINE_VERSION', defaultValue: '');
  const cartEnv = String.fromEnvironment('LYNX_CART_PATH', defaultValue: '');
  const playOnlyEnv = bool.fromEnvironment('LYNX_PLAY_ONLY', defaultValue: false);

  final args = Platform.executableArguments;
  final p = ArgParser()
    ..addOption('project-id', abbr: 'p')
    ..addOption('project-path')
    ..addOption('project-name')
    ..addOption('api-base')
    ..addOption('engine-ver')
    ..addOption('engine-version')
    ..addOption('cart-path')
    ..addFlag('cloud-read-only', defaultsTo: false)
    ..addFlag('play-only', defaultsTo: false);
  final r = p.parse(args);
  final pid = (r['project-id'] as String?)?.trim();
  final ppath = (r['project-path'] as String?)?.trim();
  final name = (r['project-name'] as String?)?.trim();
  final api = (r['api-base'] as String?)?.trim();
  final ro = r['cloud-read-only'] as bool;
  final engineVer = ((r['engine-ver'] as String?) ?? (r['engine-version'] as String?))?.trim();
  final cart = (r['cart-path'] as String?)?.trim();
  final playOnly = r['play-only'] as bool;
  return {
    'projectId': pid?.isNotEmpty == true ? pid : (fromEnv.isNotEmpty ? fromEnv : null),
    'projectPath': ppath?.isNotEmpty == true ? ppath : null,
    'projectName': name?.isNotEmpty == true ? name : (nameEnv.isNotEmpty ? nameEnv : null),
    'apiBaseOverride': api?.isNotEmpty == true ? api : (apiEnv.isNotEmpty ? apiEnv : null),
    'cloudReadOnly': ro || roEnv,
    'engineVersion': engineVer?.isNotEmpty == true
        ? engineVer
        : (engineVerEnv.isNotEmpty ? engineVerEnv : null),
    'cartPath': cart?.isNotEmpty == true ? cart : (cartEnv.isNotEmpty ? cartEnv : null),
    'playOnly': playOnly || playOnlyEnv,
  };
}
