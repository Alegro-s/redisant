import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Расширение архива проекта для импорта через Hub («Импорт ZIP»).
const String kLynxProjectZipExtension = 'lynxproject';

const _skipDirNames = {
  '.git',
  '.dart_tool',
  '__pycache__',
  'build',
  '.idea',
};

const _skipFileNames = {'.DS_Store', 'Thumbs.db'};

/// Упаковывает папку проекта (с `project.json` в корне) в zip / `.lynxproject`.
Future<String?> packProjectDirectoryToZipFile({
  required String projectRoot,
  required String outputZipPath,
}) async {
  final root = Directory(projectRoot);
  if (!await root.exists()) {
    return 'Папка проекта не найдена';
  }
  if (!await File(p.join(projectRoot, 'project.json')).exists()) {
    return 'В папке нет project.json';
  }

  try {
    final archive = Archive();
    final base = root.absolute.path;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final rel = p.relative(entity.path, from: base).replaceAll('\\', '/');
      if (rel.isEmpty || rel.startsWith('../')) continue;
      final parts = rel.split('/');
      if (parts.any(_skipDirNames.contains)) continue;
      if (entity is File && _skipFileNames.contains(p.basename(entity.path))) {
        continue;
      }
      if (entity is File) {
        archive.addFile(ArchiveFile(rel, entity.lengthSync(), await entity.readAsBytes()));
      }
    }

    var outPath = outputZipPath;
    if (!outPath.toLowerCase().endsWith('.zip') &&
        !outPath.toLowerCase().endsWith('.$kLynxProjectZipExtension')) {
      outPath = '$outPath.$kLynxProjectZipExtension';
    }
    await File(outPath).writeAsBytes(ZipEncoder().encode(archive)!);
    return null;
  } catch (e) {
    return e.toString();
  }
}

String suggestedLynxProjectZipFileName(String projectRoot) {
  final name = p.basename(projectRoot);
  return '$name.$kLynxProjectZipExtension';
}
