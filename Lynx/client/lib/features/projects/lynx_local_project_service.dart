import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/providers/auth_provider.dart';
import '../engine/models/engine_models.dart';
import '../engine/runtime/engine_binary_loader.dart';
import '../engine/runtime/engine_version_gate.dart';
import '../engine/runtime/lynx_project_templates.dart';
import '../engine/runtime/project_zip_export_io.dart';
import '../engine/screens/engine_install_hub_screen.dart';

const String kLynxLocalProjectsKey = 'nexus.local_projects_v1';

class LynxLocalProjectEntry {
  final String path;
  final String name;
  final DateTime updatedAt;

  const LynxLocalProjectEntry({
    required this.path,
    required this.name,
    required this.updatedAt,
  });
}

Future<List<LynxLocalProjectEntry>> loadLynxLocalProjects() async {
  if (kIsWeb) return const [];
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kLynxLocalProjectsKey);
  if (raw == null || raw.isEmpty) return const [];

  try {
    final decoded = jsonDecode(raw);
    final list = decoded is List ? decoded : <dynamic>[];
    final out = <LynxLocalProjectEntry>[];
    for (final e in list) {
      if (e is! Map) continue;
      final path = e['path']?.toString() ?? '';
      final name = e['name']?.toString() ?? '';
      final at = e['updatedAt'] is int
          ? e['updatedAt'] as int
          : int.tryParse(e['updatedAt']?.toString() ?? '') ?? 0;
      if (path.isEmpty || name.isEmpty) continue;
      if (!await Directory(path).exists()) continue;
      out.add(
        LynxLocalProjectEntry(
          path: path,
          name: name,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(at),
        ),
      );
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  } catch (_) {
    return const [];
  }
}

Future<void> removeLynxLocalProject(String projectPath) async {
  if (kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kLynxLocalProjectsKey);
  if (raw == null || raw.isEmpty) return;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return;
    final list = <Map<String, dynamic>>[];
    for (final e in decoded) {
      if (e is Map) {
        final path = e['path']?.toString() ?? '';
        if (path.isEmpty || path == projectPath) continue;
        list.add(Map<String, dynamic>.from(e));
      }
    }
    await prefs.setString(kLynxLocalProjectsKey, jsonEncode(list));
  } catch (_) {}
}

Future<void> rememberLynxLocalProject({
  required String projectPath,
  required String projectName,
}) async {
  if (kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kLynxLocalProjectsKey);
  final list = <Map<String, dynamic>>[];
  if (raw != null && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) {
            final path = e['path']?.toString() ?? '';
            if (path.isEmpty) continue;
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
    } catch (_) {}
  }

  list.removeWhere((e) => (e['path']?.toString() ?? '') == projectPath);
  list.insert(0, {
    'path': projectPath,
    'name': projectName,
    'updatedAt': DateTime.now().millisecondsSinceEpoch,
  });
  if (list.length > 24) {
    list.removeRange(24, list.length);
  }
  await prefs.setString(kLynxLocalProjectsKey, jsonEncode(list));
}

void openLynxLocalProjectInEditor(
  BuildContext context, {
  required String projectPath,
  required String projectName,
}) {
  context.push(
    '/engine',
    extra: {
      'projectPath': projectPath,
      'projectName': projectName,
      'mode': 'offline',
    },
  );
}

Future<void> exportLynxLocalProjectZip(
  BuildContext context, {
  required String projectRoot,
}) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Скачивание .lynxproject доступно в десктопном Lynx Launcher'),
      ),
    );
    return;
  }
  final defaultName = suggestedLynxProjectZipFileName(projectRoot);
  final savePath = await FilePicker.platform.saveFile(
    dialogTitle: 'Скачать проект',
    fileName: defaultName,
    type: FileType.custom,
    allowedExtensions: const [kLynxProjectZipExtension, 'zip'],
  );
  if (savePath == null || !context.mounted) return;
  final err = await packProjectDirectoryToZipFile(
    projectRoot: projectRoot,
    outputZipPath: savePath,
  );
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Сохранено: ${p.basename(savePath)}')),
  );
}

Future<void> showCreateLynxLocalProjectDialog(BuildContext context) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Локальный проект недоступен в браузере')),
    );
    return;
  }

  final selectedDirectory = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Папка для нового проекта',
  );
  if (selectedDirectory == null || !context.mounted) return;

  final nameController = TextEditingController();
  var selectedTemplate = kLynxProjectTemplates.first.id;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Новый проект'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Имя проекта'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedTemplate,
              decoration: const InputDecoration(labelText: 'Шаблон'),
              items: kLynxProjectTemplates
                  .map(
                    (t) => DropdownMenuItem(value: t.id, child: Text(t.name)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setLocal(() => selectedTemplate = v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) {
    nameController.dispose();
    return;
  }

  final auth = context.read<AuthProvider>();
  final projectName = nameController.text.trim().isEmpty
      ? 'Новый проект'
      : nameController.text.trim();
  nameController.dispose();
  final projectPath = p.join(selectedDirectory, projectName);
  final rec = await fetchRecommendedEngineVersion(auth.http);
  final bound = await getInstalledEngineVersionLabel();
  final runtime = await getInstalledRuntimeVersions();
  final gp = GameProject(
    projectId: 'local_${DateTime.now().millisecondsSinceEpoch}',
    displayName: projectName,
    gameTemplate: selectedTemplate,
    minNexusEngineVersion: rec,
    minLynxCoreVersion: runtime.lynxCore ?? '0.6.0-m6',
    studioEngineBoundVersion: bound,
  );
  final repoRoot = resolveLynxRepoRootFromClient();
  final err = await materializeLynxProjectTemplate(
    templateId: selectedTemplate,
    destPath: projectPath,
    repoRoot: repoRoot,
    displayName: projectName,
    projectOverrides: gp,
  );
  if (err != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    return;
  }
  await File(p.join(projectPath, '.lynx', 'engine_lock.json')).writeAsString(
    jsonEncode(
      lynxEngineLockJson(
        boundEngineVersion: bound ?? rec ?? 'unknown',
        manifestRecommended: rec,
      ),
    ),
  );
  await rememberLynxLocalProject(
    projectPath: projectPath,
    projectName: projectName,
  );
  if (!context.mounted) return;
  openLynxLocalProjectInEditor(
    context,
    projectPath: projectPath,
    projectName: projectName,
  );
  if (await getLastCachedEngineLibraryPath() == null && context.mounted) {
    unawaited(showEngineVersionInstallDialog(context, auth.http));
  }
}
