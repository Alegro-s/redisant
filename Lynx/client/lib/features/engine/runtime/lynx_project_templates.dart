import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/engine_models.dart';

/// Шаблоны локальных проектов (волна 5d).
class LynxProjectTemplate {
  final String id;
  final String name;
  final String description;
  final String? copyFromRelative;
  const LynxProjectTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.copyFromRelative,
  });
}

const List<LynxProjectTemplate> kLynxProjectTemplates = [
  LynxProjectTemplate(
    id: 'empty',
    name: 'Пустой 2D',
    description: 'Сцена main, папки assets/scenes, без контента.',
  ),
  LynxProjectTemplate(
    id: 'platformer',
    name: 'Platformer',
    description: 'Демо platformer-demo (тайлы, герой, AnimationPlayer).',
    copyFromRelative: 'platformer-demo',
  ),
  LynxProjectTemplate(
    id: 'platformer-wave2',
    name: 'Platformer + меню',
    description: 'Волна 2: menu → main, autoload, input map.',
    copyFromRelative: 'platformer-wave2',
  ),
  LynxProjectTemplate(
    id: 'tetris',
    name: 'Tetris',
    description: 'Классический Tetris на Lua + logic grids (480×640).',
    copyFromRelative: 'tetris-demo',
  ),
  LynxProjectTemplate(
    id: 'tic',
    name: 'TIC Starter',
    description: 'TIC-80 API: spr/map/btn + компактные редакторы (240×136).',
    copyFromRelative: 'tic-starter',
  ),
  LynxProjectTemplate(
    id: 'platformer-3d-room',
    name: '3D Room',
    description: 'Волна 6: комната, GLB crate, плагин lynx.3d.',
    copyFromRelative: 'platformer-demo-3d-room',
  ),
];

Future<String?> materializeLynxProjectTemplate({
  required String templateId,
  required String destPath,
  required String repoRoot,
  required String displayName,
  GameProject? projectOverrides,
}) async {
  final tpl = kLynxProjectTemplates.firstWhere(
    (t) => t.id == templateId,
    orElse: () => kLynxProjectTemplates.first,
  );
  final dest = Directory(destPath);
  if (await dest.exists()) {
    return 'Папка уже существует';
  }

  if (tpl.copyFromRelative != null) {
    final srcPath = _resolveTemplateSource(repoRoot, tpl.copyFromRelative!);
    if (srcPath == null) {
      return 'Шаблон не найден: ${tpl.copyFromRelative}';
    }
    final src = Directory(srcPath);
    await _copyTree(src, dest);
    final pj = File(p.join(destPath, 'project.json'));
    if (await pj.exists()) {
      try {
        final gp = GameProject.fromJson(
          jsonDecode(await pj.readAsString()) as Map<String, dynamic>,
        );
        final merged = GameProject(
          projectId: 'local_${DateTime.now().millisecondsSinceEpoch}',
          displayName: displayName,
          gameTemplate: gp.gameTemplate,
          startupSceneId: gp.startupSceneId,
          autoloadSceneIds: gp.autoloadSceneIds,
          designWidth: gp.designWidth,
          designHeight: gp.designHeight,
          projectMode: gp.projectMode,
          pixelPerfect: gp.pixelPerfect || gp.gameTemplate == 'tic',
          inputMap: gp.inputMap,
          tilesets: gp.tilesets,
          lynxPlugins: gp.lynxPlugins,
          minNexusEngineVersion: gp.minNexusEngineVersion,
          minLynxCoreVersion: gp.minLynxCoreVersion,
          webRuntime: gp.webRuntime,
        );
        await pj.writeAsString(jsonEncode(merged.toJson()));
      } catch (_) {}
    }
    return null;
  }

  await dest.create(recursive: true);
  await Directory(p.join(destPath, 'assets', 'sprites')).create(recursive: true);
  await Directory(p.join(destPath, 'assets', 'scripts')).create(recursive: true);
  await Directory(p.join(destPath, 'assets', 'sounds')).create(recursive: true);
  await Directory(p.join(destPath, 'scenes')).create(recursive: true);
      await Directory(p.join(destPath, '.lynx')).create(recursive: true);
  await File(p.join(destPath, 'assets', 'scripts', 'game.lua')).writeAsString(
    '-- Скрипт игры (файл в assets/scripts/, не встроен в движок)\n'
    'function update(dt)\n'
    '  -- nexus_log("tick")\n'
    'end\n',
  );

  final now = DateTime.now().toUtc().toIso8601String();
  final scene = Scene(
    id: 'main',
    name: 'Main',
    layers: Scene.defaultLayers(),
    createdAt: DateTime.now().toUtc(),
    modifiedAt: DateTime.now().toUtc(),
  );
  await File(p.join(destPath, 'scenes', 'main.json')).writeAsString(
    jsonEncode(scene.toJson()),
  );

  final gp = projectOverrides ??
      GameProject(
        projectId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        displayName: displayName,
        gameTemplate: templateId,
      );
  await File(p.join(destPath, 'project.json')).writeAsString(jsonEncode(gp.toJson()));
  await File(p.join(destPath, 'project.nexus')).writeAsString(
    jsonEncode({'name': displayName, 'version': '1.0.0', 'local': true, 'template': templateId}),
  );
  await Directory(p.join(destPath, '.lynx')).create(recursive: true);
  await File(p.join(destPath, '.lynx', 'engine_lock.json')).writeAsString(
    jsonEncode(lynxEngineLockJson(boundEngineVersion: gp.studioEngineBoundVersion ?? 'unknown')),
  );
  return null;
}

Map<String, dynamic> lynxEngineLockJson({
  required String boundEngineVersion,
  String? manifestRecommended,
}) =>
    {
      'format': 'lynx_engine_lock',
      'schema': 1,
      'boundEngineVersion': boundEngineVersion,
      'boundAt': DateTime.now().toUtc().toIso8601String(),
      if (manifestRecommended != null) 'manifestRecommendedAtCreate': manifestRecommended,
    };

Future<void> _copyTree(Directory src, Directory dest) async {
  await dest.create(recursive: true);
  await for (final entity in src.list(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: src.path);
    if (rel.replaceAll('\\', '/').startsWith('.git/')) continue;
    if (rel.contains('.dart_tool')) continue;
    final target = p.join(dest.path, rel);
    if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
    }
  }
}

/// Путь к встроенному шаблону (MSI `templates/` или dev `projects/`).
String? resolveTemplateProjectDirectory(String templateRelative) {
  return _resolveTemplateSource(resolveLynxRepoRootFromClient(), templateRelative);
}

String? _resolveTemplateSource(String repoRoot, String templateId) {
  final base = p.basename(templateId);
  final candidates = [
    p.join(repoRoot, 'templates', base),
    p.join(repoRoot, 'templates', templateId),
    p.join(repoRoot, 'projects', base),
    p.join(repoRoot, templateId),
    p.join(repoRoot, 'projects', templateId),
  ];
  for (final c in candidates) {
    if (Directory(c).existsSync()) return p.normalize(c);
  }
  return null;
}

String resolveLynxRepoRootFromClient() {
  if (!kIsWeb) {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final nextToExe = p.join(exeDir, 'templates');
      if (Directory(nextToExe).existsSync()) {
        return p.normalize(exeDir);
      }
      final parentTemplates = p.normalize(p.join(exeDir, '..', 'templates'));
      if (Directory(parentTemplates).existsSync()) {
        return p.normalize(p.join(exeDir, '..'));
      }
      final local = Platform.environment['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) {
        final appData = p.join(local, 'Lynx', 'templates');
        if (Directory(appData).existsSync()) {
          return p.normalize(p.join(local, 'Lynx'));
        }
      }
    } catch (_) {}
  }
  var dir = Directory.current.path;
  if (p.basename(dir) == 'client') {
    return p.normalize(p.join(dir, '..'));
  }
  return p.normalize(dir);
}
