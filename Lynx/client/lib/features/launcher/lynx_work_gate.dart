import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../engine/models/engine_models.dart';
import '../engine/runtime/engine_binary_loader.dart';
import '../engine/runtime/engine_version_gate.dart';
import '../engine/screens/engine_install_hub_screen.dart';
import 'engine_version_picker_dialog.dart';

/// L19c/L19d — выбор и установка версии ядра перед запуском Engine.
Future<String?> resolveEngineVersionForLaunch(
  BuildContext context, {
  required Dio dio,
  String? projectPath,
}) async {
  if (kIsWeb) return null;

  String? required;
  if (projectPath != null && projectPath.isNotEmpty) {
    try {
      final pjFile = File(p.join(projectPath, 'project.json'));
      if (await pjFile.exists()) {
        final pj = GameProject.fromJson(
          jsonDecode(await pjFile.readAsString()) as Map<String, dynamic>,
        );
        required = pj.studioEngineBoundVersion ?? pj.minNexusEngineVersion;
      }
      final lockFile = File(p.join(projectPath, '.lynx', 'engine_lock.json'));
      if (await lockFile.exists()) {
        final lock = jsonDecode(await lockFile.readAsString()) as Map<String, dynamic>;
        final bound = lock['boundEngineVersion']?.toString();
        if (bound != null && bound.isNotEmpty) required = bound;
      }
    } catch (_) {}
  }

  var installed = await listInstalledLynxEngineVersions();
  if (installed.isEmpty) {
    if (!context.mounted) return null;
    return showEngineVersionInstallDialog(context, dio);
  }

  if (required != null && required.isNotEmpty) {
    final compatible = installed
        .where((v) => compareEngineVersions(v, required!) >= 0)
        .toList();
    if (compatible.isEmpty) {
      if (!context.mounted) return null;
      final install = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Нужна новая версия ядра'),
          content: Text('Проект требует Lynx Engine ≥ $required. Установить из центра ядер?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Установить')),
          ],
        ),
      );
      if (install == true && context.mounted) {
        await context.push('/engine-install');
        installed = await listInstalledLynxEngineVersions();
      }
      if (!context.mounted) return null;
      return showEngineVersionInstallDialog(context, dio);
    }
    if (compatible.length == 1) return compatible.first;
    if (!context.mounted) return compatible.first;
    return showEngineVersionPickerDialog(
      context,
      dio: dio,
      requiredVersion: required,
      installedVersions: compatible,
    );
  }

  if (installed.length == 1) return installed.first;
  if (!context.mounted) return installed.first;
  return showEngineVersionPickerDialog(
    context,
    dio: dio,
    installedVersions: installed,
  );
}
