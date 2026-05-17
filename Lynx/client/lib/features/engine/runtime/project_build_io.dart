import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

bool _excludeRelativePath(String rel) {
  final n = p.normalize(rel).replaceAll('\\', '/');
  if (n == '.git' || n.startsWith('.git/')) return true;
  if (n.startsWith('.dart_tool/')) return true;
  if (n.startsWith('build/')) return true;
  if (n.startsWith('.nexus/')) return true;
  return false;
}

Future<String?> exportDesktopProjectBundle({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
}) async {
  final rootDir = Directory(projectRoot);
  if (!await rootDir.exists()) {
    return 'Папка проекта не найдена';
  }

  await Directory(outputDirectory).create(recursive: true);
  final dataDir = Directory(p.join(outputDirectory, 'game_data'));
  await dataDir.create(recursive: true);

  await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: projectRoot);
    if (_excludeRelativePath(rel)) continue;
    final destPath = p.join(dataDir.path, rel);
    await Directory(p.dirname(destPath)).create(recursive: true);
    await entity.copy(destPath);
  }

  if (engineLibraryAbsolutePath != null &&
      engineLibraryAbsolutePath.isNotEmpty) {
    final lib = File(engineLibraryAbsolutePath);
    if (await lib.exists()) {
      final binDir = Directory(p.join(outputDirectory, 'bin'));
      await binDir.create(recursive: true);
      final name = p.basename(engineLibraryAbsolutePath);
      await lib.copy(p.join(binDir.path, name));
    }
  }

  final readme = File(p.join(outputDirectory, 'README_LYNX_BUILD.txt'));
  await readme.writeAsString(
    'Lynx — экспорт данных для запуска или бэкапа\n'
    '\n'
    'Папка game_data — полная копия проекта (без .git и служебных каталогов).\n'
    'Откройте её в приложении Lynx как локальный проект: файл проекта — game_data/project.json\n'
    '\n'
    'Папка bin (если есть) — скопированная нативная библиотека движка (engine.dll / libengine.so),\n'
    'чтобы на целевой машине не пришлось заново качать артефакт с сервера.\n'
    'Клиент Lynx всё равно подставляет этот путь из кэша при игре.\n',
    encoding: utf8,
  );

  if (Platform.isWindows) {
    final bat = File(p.join(outputDirectory, 'open_game_data_folder.bat'));
    await bat.writeAsString(
      r'@echo off' '\r\n'
      r'cd /d "%~dp0game_data"' '\r\n'
      r'start "" .' '\r\n',
      encoding: utf8,
    );
  }

  return null;
}
