import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

Future<String?> extractZipArchiveToDirectory({
  required File zipFile,
  required Directory destinationDirectory,
}) async {
  try {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final base = destinationDirectory.absolute.path;
    for (final file in archive) {
      final name = file.name.replaceAll('\\', '/');
      if (name.isEmpty || name.startsWith('/') || name.contains('../')) {
        continue;
      }
      final outPath = p.normalize(p.join(base, name));
      if (!outPath.startsWith(base)) {
        return 'Небезопасный путь в архиве';
      }
      if (file.isFile) {
        final f = File(outPath);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    return null;
  } catch (e) {
    return e.toString();
  }
}

Future<String?> findNexusProjectRoot(String extractRoot) async {
  final direct = File(p.join(extractRoot, 'project.json'));
  if (await direct.exists()) return extractRoot;

  final dir = Directory(extractRoot);
  if (!await dir.exists()) return null;

  await for (final e in dir.list(followLinks: false)) {
    if (e is Directory) {
      final inner = File(p.join(e.path, 'project.json'));
      if (await inner.exists()) return e.path;
    }
  }
  return null;
}
