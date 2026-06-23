import 'dart:io';

import 'package:path/path.dart' as p;

/// E21c — импорт пакета ассетов из Cloud в папку проекта.
Future<String?> importCloudAssetPackage({
  required String projectRoot,
  required String downloadedZipPath,
  String subfolder = 'assets/cloud',
}) async {
  final zip = File(downloadedZipPath);
  if (!await zip.exists()) return 'ZIP не найден: $downloadedZipPath';
  final dest = Directory(p.join(projectRoot, subfolder));
  await dest.create(recursive: true);
  // Распаковка делегируется существующему zip helper проекта при наличии;
  // здесь — минимальный контракт: положить архив и вернуть путь.
  final target = File(p.join(dest.path, p.basename(downloadedZipPath)));
  await zip.copy(target.path);
  return null;
}

String cloudAssetImportHint(String projectRoot, {String subfolder = 'assets/cloud'}) =>
    p.join(projectRoot, subfolder);
