import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

const String kLynxPackFileName = 'lynx_game_data.lynxpack';

bool _excludeRelativePath(String rel) {
  final n = p.normalize(rel).replaceAll('\\', '/');
  if (n == '.git' || n.startsWith('.git/')) return true;
  if (n.startsWith('.dart_tool/')) return true;
  if (n.startsWith('build/')) return true;
  if (n.startsWith('.nexus/')) return true;
  return false;
}

/// Копирует проект в [destDirectory] (структура game_data).
Future<void> copyProjectToGameData({
  required String projectRoot,
  required String destDirectory,
}) async {
  final rootDir = Directory(projectRoot);
  if (!await rootDir.exists()) {
    throw StateError('Папка проекта не найдена: $projectRoot');
  }
  final dataDir = Directory(destDirectory);
  if (await dataDir.exists()) {
    await dataDir.delete(recursive: true);
  }
  await dataDir.create(recursive: true);

  await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: projectRoot);
    if (_excludeRelativePath(rel)) continue;
    final destPath = p.join(dataDir.path, rel);
    await Directory(p.dirname(destPath)).create(recursive: true);
    await entity.copy(destPath);
  }
}

/// ZIP-архив проекта для вшивания в APK/IPA.
Future<File> writeLynxGamePack({
  required String projectRoot,
  required String outputFilePath,
}) async {
  final archive = Archive();
  final rootDir = Directory(projectRoot);
  await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: projectRoot);
    if (_excludeRelativePath(rel)) continue;
    final bytes = await entity.readAsBytes();
    archive.addFile(ArchiveFile(rel.replaceAll('\\', '/'), bytes.length, bytes));
  }
  final out = File(outputFilePath);
  await out.parent.create(recursive: true);
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('Не удалось создать $kLynxPackFileName');
  }
  await out.writeAsBytes(encoded);
  return out;
}

Future<void> extractLynxPackBytes(List<int> zipBytes, String destDirectory) async {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final dest = Directory(destDirectory);
  await dest.create(recursive: true);
  for (final file in archive) {
    if (file.isFile) {
      final outPath = p.join(dest.path, file.name);
      await Directory(p.dirname(outPath)).create(recursive: true);
      await File(outPath).writeAsBytes(file.content as List<int>);
    }
  }
}

Future<Map<String, dynamic>> readProjectManifest(String projectRoot) async {
  final pj = File(p.join(projectRoot, 'project.json'));
  if (!await pj.exists()) return {};
  return jsonDecode(await pj.readAsString()) as Map<String, dynamic>;
}
