import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'embedded_game_pack_io.dart';
import 'lynx_cart_io.dart';

/// Пресеты экспорта (волна 3).
enum LynxExportPreset {
  windows,
  web,
  android,
  cart,
  /// Только `game_data` (как раньше).
  dataBundle,
}

class LynxExportResult {
  final LynxExportPreset preset;
  final String outputDirectory;
  final List<String> artifactPaths;
  const LynxExportResult({
    required this.preset,
    required this.outputDirectory,
    required this.artifactPaths,
  });
}

Future<String?> runLynxExport({
  required String projectRoot,
  required String outputDirectory,
  required LynxExportPreset preset,
  String? engineLibraryAbsolutePath,
  String? clientRootForWebStaging,
}) async {
  final rootDir = Directory(projectRoot);
  if (!await rootDir.exists()) {
    return 'Папка проекта не найдена';
  }

  await Directory(outputDirectory).create(recursive: true);
  final manifest = await readProjectManifest(projectRoot);
  final projectName = manifest['displayName'] as String? ?? p.basename(projectRoot);

  switch (preset) {
    case LynxExportPreset.dataBundle:
      return _exportDataBundle(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
      );
    case LynxExportPreset.windows:
      return _exportWindows(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        projectName: projectName,
        manifest: manifest,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
      );
    case LynxExportPreset.web:
      return _exportWeb(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        projectName: projectName,
        manifest: manifest,
        clientRootForWebStaging: clientRootForWebStaging,
      );
    case LynxExportPreset.android:
      return _exportAndroid(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        projectName: projectName,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
      );
    case LynxExportPreset.cart:
      return _exportCart(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        manifest: manifest,
      );
  }
}

Future<String?> _exportCart({
  required String projectRoot,
  required String outputDirectory,
  required Map<String, dynamic> manifest,
}) async {
  final name = manifest['displayName'] as String? ?? p.basename(projectRoot);
  final safe = name.replaceAll(RegExp(r'[^\w\-]+'), '_');
  final out = p.join(outputDirectory, '$safe$kLynxCartExtension');
  await packProjectToLynxCart(projectRoot: projectRoot, outputPath: out);
  return null;
}

Future<String?> _exportDataBundle({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
}) async {
  final dataDir = p.join(outputDirectory, 'game_data');
  await copyProjectToGameData(projectRoot: projectRoot, destDirectory: dataDir);
  await _copyEngineBin(engineLibraryAbsolutePath, outputDirectory);
  await _writeReadme(outputDirectory, preset: LynxExportPreset.dataBundle);
  return null;
}

Future<String?> _exportWindows({
  required String projectRoot,
  required String outputDirectory,
  required String projectName,
  required Map<String, dynamic> manifest,
  String? engineLibraryAbsolutePath,
}) async {
  final stage = p.join(outputDirectory, 'windows');
  final dataDir = p.join(stage, 'game_data');
  await copyProjectToGameData(projectRoot: projectRoot, destDirectory: dataDir);
  await _copyEngineBin(engineLibraryAbsolutePath, stage);

  final windows3dRuntime =
      manifest['windows3dRuntime']?.toString() ?? 'canvas_preview';
  final meta = {
    'format': 'lynx_export_v1',
    'preset': 'windows',
    'projectName': projectName,
    'entrypoint': 'lib/main_player.dart',
    'buildHint':
        'cd client && flutter build windows -t lib/main_player.dart --release',
    'windows3dRuntime': windows3dRuntime,
  };
  await File(p.join(stage, 'lynx_export.json'))
      .writeAsString(const JsonEncoder.withIndent('  ').convert(meta));

  if (Platform.isWindows) {
    await File(p.join(stage, 'Play.bat')).writeAsString(
      '@echo off\r\n'
      'cd /d "%~dp0"\r\n'
      'if exist "client.exe" (\r\n'
      '  start "" "client.exe"\r\n'
      '  exit /b 0\r\n'
      ')\r\n'
      'echo Положите Lynx Player (client.exe) сюда после flutter build windows.\r\n'
      'echo Рядом должны быть папки game_data и bin.\r\n'
      'pause\r\n',
    );
  }

  final zipPath = p.join(outputDirectory, '${_safeFileName(projectName)}_windows.zip');
  await _zipDirectory(stage, zipPath);

  await _writeReadme(outputDirectory, preset: LynxExportPreset.windows);
  return null;
}

Future<String?> _exportWeb({
  required String projectRoot,
  required String outputDirectory,
  required String projectName,
  required Map<String, dynamic> manifest,
  String? clientRootForWebStaging,
}) async {
  final stage = p.join(outputDirectory, 'web');
  final dataDir = p.join(stage, 'game_data');
  await copyProjectToGameData(projectRoot: projectRoot, destDirectory: dataDir);

  if (clientRootForWebStaging != null && clientRootForWebStaging.isNotEmpty) {
    final webDir = p.join(clientRootForWebStaging, 'web', 'game_data');
    await copyProjectToGameData(projectRoot: projectRoot, destDirectory: webDir);
  }

  final webRuntime = manifest['webRuntime']?.toString() ?? 'web_scene_engine';
  final meta = {
    'format': 'lynx_export_v1',
    'preset': 'web',
    'projectName': projectName,
    'entrypoint': 'lib/main_player.dart',
    'buildHint': 'cd client && flutter build web -t lib/main_player.dart --release',
    'runtimePath': 'game_data',
    'webRuntime': webRuntime,
  };
  await File(p.join(stage, 'lynx_export.json'))
      .writeAsString(const JsonEncoder.withIndent('  ').convert(meta));

  await _writeReadme(outputDirectory, preset: LynxExportPreset.web);
  return null;
}

Future<String?> _exportAndroid({
  required String projectRoot,
  required String outputDirectory,
  required String projectName,
  String? engineLibraryAbsolutePath,
}) async {
  final stage = p.join(outputDirectory, 'android');
  await Directory(stage).create(recursive: true);

  final packPath = p.join(stage, kLynxPackFileName);
  await writeLynxGamePack(projectRoot: projectRoot, outputFilePath: packPath);

  final assetsHintPath = p.join(stage, 'COPY_TO_FLUTTER_ASSETS.txt');
  await File(assetsHintPath).writeAsString(
    'Скопируйте $kLynxPackFileName в:\n'
    '  client/assets/$kLynxPackFileName\n'
    'и добавьте в pubspec.yaml:\n'
    '  assets:\n'
    '    - assets/$kLynxPackFileName\n'
    '\n'
    'Соберите Player:\n'
    '  flutter build apk -t lib/main_player.dart --release\n'
    '\n'
    'libengine.so → android/app/src/main/jniLibs/<abi>/\n'
    '(см. engine/scripts/build-apk.ps1)\n',
  );

  if (engineLibraryAbsolutePath != null && engineLibraryAbsolutePath.isNotEmpty) {
    final lib = File(engineLibraryAbsolutePath);
    if (await lib.exists()) {
      final jni = Directory(p.join(stage, 'jniLibs', 'arm64-v8a'));
      await jni.create(recursive: true);
      await lib.copy(p.join(jni.path, 'libengine.so'));
    }
  }

  final meta = {
    'format': 'lynx_export_v1',
    'preset': 'android',
    'projectName': projectName,
    'packFile': kLynxPackFileName,
    'entrypoint': 'lib/main_player.dart',
  };
  await File(p.join(stage, 'lynx_export.json'))
      .writeAsString(const JsonEncoder.withIndent('  ').convert(meta));

  await _writeReadme(outputDirectory, preset: LynxExportPreset.android);
  return null;
}

Future<void> _copyEngineBin(String? engineLibraryAbsolutePath, String outputDirectory) async {
  if (engineLibraryAbsolutePath == null || engineLibraryAbsolutePath.isEmpty) {
    return;
  }
  final lib = File(engineLibraryAbsolutePath);
  if (!await lib.exists()) return;
  final binDir = Directory(p.join(outputDirectory, 'bin'));
  await binDir.create(recursive: true);
  await lib.copy(p.join(binDir.path, p.basename(engineLibraryAbsolutePath)));
}

Future<void> _zipDirectory(String sourceDir, String zipPath) async {
  final archive = Archive();
  final root = Directory(sourceDir);
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: sourceDir).replaceAll('\\', '/');
    final bytes = await entity.readAsBytes();
    archive.addFile(ArchiveFile(rel, bytes.length, bytes));
  }
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) return;
  await File(zipPath).writeAsBytes(encoded);
}

String _safeFileName(String name) {
  return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
}

Future<void> _writeReadme(String outputDirectory, {required LynxExportPreset preset}) async {
  final buf = StringBuffer()
    ..writeln('Lynx Export — ${preset.name}')
    ..writeln()
    ..writeln('См. Lynx/docs/EXPORT.md и scripts/export-player.ps1')
    ..writeln();
  switch (preset) {
    case LynxExportPreset.windows:
      buf.writeln('windows/ — game_data + bin + ZIP для itch.io');
      buf.writeln('Соберите Player и положите client.exe в windows/');
      break;
    case LynxExportPreset.web:
      buf.writeln('web/game_data — статика для flutter build web (main_player.dart)');
      break;
    case LynxExportPreset.android:
      buf.writeln('android/lynx_game_data.lynxpack — в assets + jniLibs');
      break;
    case LynxExportPreset.dataBundle:
      buf.writeln('game_data — копия проекта для Player');
      break;
    case LynxExportPreset.cart:
      buf.writeln('.lynxcart — portable cart для Cloud Arcade');
      break;
  }
  await File(p.join(outputDirectory, 'README_LYNX_EXPORT.txt')).writeAsString(buf.toString());
}
