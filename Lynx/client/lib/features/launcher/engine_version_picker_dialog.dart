import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../engine/runtime/engine_binary_loader.dart';
import '../engine/runtime/engine_version_gate.dart';

/// L19c — выбор версии ядра при открытии проекта.
Future<String?> showEngineVersionPickerDialog(
  BuildContext context, {
  required Dio dio,
  String? requiredVersion,
  List<String>? installedVersions,
}) async {
  final installed = installedVersions ?? await listInstalledLynxEngineVersions();
  final manifest = await fetchEngineManifestSnapshot(dio);
  final remote = manifest?.releases.map((e) => e['version']?.toString()).whereType<String>().toList() ??
      const <String>[];
  final choices = <String>{
    ...installed,
    ...remote,
    if (requiredVersion != null && requiredVersion.isNotEmpty) requiredVersion,
  }.toList()
    ..sort((a, b) => compareEngineVersions(b, a));

  if (choices.isEmpty) {
    return requiredVersion;
  }
  if (choices.length == 1) return choices.first;

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Версия ядра Lynx Engine'),
      content: SizedBox(
        width: 360,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (requiredVersion != null && requiredVersion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Проект требует ≥ $requiredVersion'),
              ),
            for (final v in choices)
              ListTile(
                title: Text('Lynx Engine $v'),
                subtitle: Text(installed.contains(v) ? 'Установлено' : 'Скачать из Hub'),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
      ],
    ),
  );
}
