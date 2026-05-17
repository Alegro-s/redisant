import 'dart:io';

import 'package:args/args.dart';

Map<String, Object?> readEditorBootstrapRaw() {
  const fromEnv = String.fromEnvironment('NEXUS_PROJECT_ID', defaultValue: '');
  const nameEnv = String.fromEnvironment('NEXUS_PROJECT_NAME', defaultValue: '');
  const apiEnv = String.fromEnvironment('NEXUS_API_BASE', defaultValue: '');
  const roEnv = bool.fromEnvironment('NEXUS_CLOUD_READONLY', defaultValue: false);

  final args = Platform.executableArguments;
  final p = ArgParser()
    ..addOption('project-id', abbr: 'p')
    ..addOption('project-name')
    ..addOption('api-base')
    ..addFlag('cloud-read-only', defaultsTo: false);
  final r = p.parse(args);
  final pid = (r['project-id'] as String?)?.trim();
  final name = (r['project-name'] as String?)?.trim();
  final api = (r['api-base'] as String?)?.trim();
  final ro = r['cloud-read-only'] as bool;
  return {
    'projectId': pid?.isNotEmpty == true ? pid : (fromEnv.isNotEmpty ? fromEnv : null),
    'projectName': name?.isNotEmpty == true ? name : (nameEnv.isNotEmpty ? nameEnv : null),
    'apiBaseOverride': api?.isNotEmpty == true ? api : (apiEnv.isNotEmpty ? apiEnv : null),
    'cloudReadOnly': ro || roEnv,
  };
}
