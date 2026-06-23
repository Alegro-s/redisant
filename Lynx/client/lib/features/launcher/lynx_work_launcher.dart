import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';
import '../auth/providers/auth_provider.dart';
import '../engine/runtime/engine_binary_loader.dart';
import '../engine/providers/scene_provider.dart';
import '../engine/screens/engine_main_page.dart';
import 'lynx_engine_launcher.dart';
import 'lynx_work_gate.dart';

class LynxWorkLaunchResult {
  LynxWorkLaunchResult.ok({this.spawned = false}) : ok = true, message = null;
  LynxWorkLaunchResult.fail(this.message) : ok = false, spawned = false;
  final bool ok;
  final String? message;
  final bool spawned;
}

/// Launcher → Lynx Engine (волна 16 / Android Activity).
Future<LynxWorkLaunchResult> launchLynxWork({
  required BuildContext context,
  String? projectId,
  String? projectPath,
  String? projectName,
  bool cloudReadOnly = false,
  String? engineVersion,
}) async {
  final auth = context.read<AuthProvider>();
  final settings = context.read<SettingsProvider>();

  var resolvedEngineVer = engineVersion;
  if (resolvedEngineVer == null && !kIsWeb && lynxEngineSpawnSupported) {
    resolvedEngineVer = await resolveEngineVersionForLaunch(
      context,
      dio: auth.http,
      projectPath: projectPath,
    );
    if (!context.mounted) return LynxWorkLaunchResult.fail('Контекст недоступен');
  }

  String? engineExe;
  if (!kIsWeb && lynxEngineSpawnSupported) {
    engineExe = resolveLynxEngineExecutable(
      configuredPath: settings.nexusEditorExecutablePath,
    );
    engineExe ??= await resolveInstalledLynxEngineExecutable(
      preferredVersion: resolvedEngineVer,
    );
  }

  if (!kIsWeb && Platform.isAndroid) {
    const ch = MethodChannel('lynx/engine_launcher');
    try {
      await ch.invokeMethod<void>('launchEngine', {
        if (projectPath != null && projectPath.isNotEmpty) 'projectPath': projectPath,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
        if (projectName != null && projectName.isNotEmpty) 'projectName': projectName,
        'apiBase': auth.dioBaseUrl,
        if (resolvedEngineVer != null && resolvedEngineVer.isNotEmpty) 'engineVer': resolvedEngineVer,
        'cloudReadOnly': cloudReadOnly,
      });
      return LynxWorkLaunchResult.ok(spawned: true);
    } catch (e) {
      return LynxWorkLaunchResult.fail('$e');
    }
  }

  if (lynxEngineSpawnSupported) {
    final exe = engineExe ??
        resolveLynxEngineExecutable(
          configuredPath: settings.nexusEditorExecutablePath,
        );
    if (exe != null && exe.isNotEmpty) {
      final args = <String>[
        if (projectPath != null && projectPath.isNotEmpty) ...[
          '--project-path',
          projectPath,
        ] else if (projectId != null && projectId.isNotEmpty) ...[
          '--project-id',
          projectId,
          '--api-base',
          auth.dioBaseUrl,
        ],
        if (projectName != null && projectName.isNotEmpty) ...[
          '--project-name',
          projectName,
        ],
        if (resolvedEngineVer != null && resolvedEngineVer.isNotEmpty) ...[
          '--engine-ver',
          resolvedEngineVer,
        ],
        if (cloudReadOnly) '--cloud-read-only',
      ];
      final r = await launchLynxEngineProcess(executablePath: exe, arguments: args);
      if (r.ok) return LynxWorkLaunchResult.ok(spawned: true);
      return LynxWorkLaunchResult.fail(r.message);
    }
    // LynxEngine.exe не найден — открываем редактор внутри Launcher (без отдельного процесса).
  }

  if (!context.mounted) return LynxWorkLaunchResult.fail('Контекст недоступен');
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => SceneProvider(),
        child: EngineMainPage(
          projectId: projectId,
          projectPath: projectPath,
          projectName: projectName,
          cloudReadOnly: cloudReadOnly,
        ),
      ),
    ),
  );
  return LynxWorkLaunchResult.ok();
}

Future<void> launchLynxWorkOrSnackBar(
  BuildContext context, {
  String? projectId,
  String? projectPath,
  String? projectName,
  bool cloudReadOnly = false,
  String? engineVersion,
}) async {
  final r = await launchLynxWork(
    context: context,
    projectId: projectId,
    projectPath: projectPath,
    projectName: projectName,
    cloudReadOnly: cloudReadOnly,
    engineVersion: engineVersion,
  );
  if (!context.mounted) return;
  if (!r.ok && r.message != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message!)));
  } else if (r.spawned) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lynx Engine запущен')),
    );
  }
}
