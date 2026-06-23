import 'dart:io';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import 'nexus_editor_launcher.dart';

export 'nexus_editor_launcher.dart';

class LynxEngineLaunchResult {
  LynxEngineLaunchResult.ok({this.inProcess = false})
      : ok = true,
        message = null;
  LynxEngineLaunchResult.fail(this.message)
      : ok = false,
        inProcess = false;
  final bool ok;
  final String? message;
  final bool inProcess;
}

bool get lynxEngineSpawnSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

String? resolveLynxEngineExecutable({String? configuredPath}) {
  final configured = configuredPath?.trim() ?? '';
  if (configured.isNotEmpty && File(configured).existsSync()) {
    return configured;
  }
  if (!lynxEngineSpawnSupported) return null;
  final self = Platform.resolvedExecutable;
  final dir = File(self).parent.path;
  for (final name in ['LynxEngine.exe', 'lynx_engine.exe', 'LynxEditor.exe', 'lynx_editor.exe']) {
    final candidate = '$dir${Platform.pathSeparator}$name';
    if (File(candidate).existsSync()) return candidate;
  }
  return configured.isNotEmpty ? configured : null;
}

Future<LynxEngineLaunchResult> launchLynxEngineProcess({
  required String? executablePath,
  required List<String> arguments,
}) {
  return launchNexusEditorProcess(
    executablePath: executablePath,
    arguments: arguments,
  ).then((r) => r.ok
      ? LynxEngineLaunchResult.ok()
      : LynxEngineLaunchResult.fail(r.message));
}
