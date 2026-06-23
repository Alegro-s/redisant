import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'embedded_game_pack_io.dart';
import 'lynx_android_toolchain_io.dart';
import 'lynx_export_io.dart';
import 'lynx_project_templates.dart';

typedef LynxBuildLog = void Function(String message);

/// Корень Flutter-пакета `client` (репозиторий или dev).
Future<String?> resolveLynxClientRoot({String? projectRoot}) async {
  if (kIsWeb) return null;
  final seen = <String>{};
  void add(String? path) {
    if (path == null || path.isEmpty) return;
    final n = p.normalize(path);
    if (n.isNotEmpty) seen.add(n);
  }

  if (projectRoot != null && projectRoot.isNotEmpty) {
    add(p.join(projectRoot, '..', 'client'));
    add(p.join(projectRoot, '..', '..', 'client'));
  }
  final repo = resolveLynxRepoRootFromClient();
  add(p.join(repo, 'client'));
  try {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    add(p.join(exeDir, 'sdk', 'client'));
    add(p.join(exeDir, 'client'));
    add(p.join(exeDir, '..', 'client'));
  } catch (_) {}
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    add(p.join(local, 'Lynx', 'sdk', 'client'));
    add(p.join(local, 'Lynx', 'client'));
  }

  for (final root in seen) {
    if (await File(p.join(root, 'pubspec.yaml')).exists()) {
      return root;
    }
  }
  return null;
}

/// Встроенный Player из MSI (`player/win/client.exe`).
Future<String?> resolveBundledPlayerWindowsTemplate() async {
  if (kIsWeb || !Platform.isWindows) return null;
  final candidates = <String>[];
  try {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    candidates.add(p.join(exeDir, 'player', 'win'));
    candidates.add(p.join(exeDir, 'player', 'windows'));
  } catch (_) {}
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    candidates.add(p.join(local, 'Lynx', 'player', 'win'));
  }

  for (final dir in candidates) {
    for (final name in ['LynxPlayer.exe', 'client.exe']) {
      if (await File(p.join(dir, name)).exists()) {
        return p.normalize(dir);
      }
    }
  }
  return null;
}

class LynxFullBuildResult {
  final List<String> artifactPaths;
  final String outputDirectory;
  const LynxFullBuildResult({
    required this.artifactPaths,
    required this.outputDirectory,
  });
}

Future<String> _playerExeNameInDir(String dir) async {
  for (final name in ['LynxPlayer.exe', 'client.exe']) {
    if (await File(p.join(dir, name)).exists()) return name;
  }
  return 'client.exe';
}

/// Полная сборка Windows: EXE + game_data + engine + ZIP.
Future<String?> buildWindowsGameRelease({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
  LynxBuildLog? onLog,
}) async {
  if (kIsWeb) return 'Сборка Windows недоступна в браузере';
  if (!Platform.isWindows) {
    return 'Сборка Windows.exe доступна только на Windows';
  }

  await Directory(outputDirectory).create(recursive: true);
  final manifest = await readProjectManifest(projectRoot);
  final projectName =
      manifest['displayName']?.toString() ?? p.basename(projectRoot);
  final safeName = _safeFileName(projectName);
  final distDir = p.join(outputDirectory, safeName);

  if (await Directory(distDir).exists()) {
    await Directory(distDir).delete(recursive: true);
  }

  String? releaseSrc;
  final clientRoot = await resolveLynxClientRoot(projectRoot: projectRoot);

  if (clientRoot != null) {
    onLog?.call('flutter pub get…');
    var code = await _runCmd('flutter', ['pub', 'get'], clientRoot, onLog);
    if (code != 0) return 'flutter pub get завершился с ошибкой ($code)';

    onLog?.call('Сборка Lynx Player (Windows EXE)…');
    code = await _runCmd(
      'flutter',
      ['build', 'windows', '-t', 'lib/main_player.dart', '--release'],
      clientRoot,
      onLog,
    );
    if (code != 0) {
      return 'flutter build windows не удался (код $code). Проверьте Flutter SDK и Visual Studio Build Tools.';
    }
    final built = p.join(
      clientRoot,
      'build',
      'windows',
      'x64',
      'runner',
      'Release',
    );
    if (!await File(p.join(built, 'client.exe')).exists()) {
      return 'Не найден client.exe после сборки: $built';
    }
    releaseSrc = built;
  } else {
    releaseSrc = await resolveBundledPlayerWindowsTemplate();
    if (releaseSrc == null) {
      return 'Не найден каталог client и встроенный Player. '
          'Откройте проект из репозитория Lynx или переустановите Launcher с Player.';
    }
    onLog?.call('Копируем встроенный Lynx Player…');
  }

  onLog?.call('Упаковка game_data и движка…');
  await _copyTree(releaseSrc, distDir);
  await copyProjectToGameData(
    projectRoot: projectRoot,
    destDirectory: p.join(distDir, 'game_data'),
  );
  await _copyEngineBin(engineLibraryAbsolutePath, distDir);

  await File(p.join(distDir, 'Play.bat')).writeAsString(
    '@echo off\r\n'
    'cd /d "%~dp0"\r\n'
    'if exist "LynxPlayer.exe" (start "" "LynxPlayer.exe") else start "" "client.exe"\r\n',
  );

  final zipPath = p.join(outputDirectory, '${safeName}_windows.zip');
  await _zipDirectory(distDir, zipPath);

  await File(p.join(outputDirectory, 'README_BUILD.txt')).writeAsString(
    'Lynx Player — Windows\n'
    'Запуск: $safeName\\client.exe или Play.bat\n'
    'EXE: ${p.join(distDir, 'client.exe')}\n'
    'ZIP: $zipPath\n',
  );

  onLog?.call('Готово: ${p.join(distDir, 'client.exe')}');
  return null;
}

/// Полная сборка Android APK с вшитым проектом.
Future<String?> buildAndroidGameRelease({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
  LynxBuildLog? onLog,
}) async {
  if (kIsWeb) return 'Сборка APK недоступна в браузере';

  final clientRoot = await resolveLynxClientRoot(projectRoot: projectRoot);
  if (clientRoot == null) {
    return 'Не найден каталог client для сборки APK. Откройте Lynx из репозитория с Flutter SDK.';
  }

  await Directory(outputDirectory).create(recursive: true);
  final manifest = await readProjectManifest(projectRoot);
  final projectName =
      manifest['displayName']?.toString() ?? p.basename(projectRoot);
  final safeName = _safeFileName(projectName);

  onLog?.call('Проверка Android SDK / NDK / Java…');
  final toolchainErr = await ensureLynxAndroidToolchain(
    clientRoot: clientRoot,
    onLog: onLog,
  );
  if (toolchainErr != null) return toolchainErr;
  final androidEnv = await loadLynxAndroidEnv();

  onLog?.call('Подготовка lynx_game_data.lynxpack…');
  final assetsDir = p.join(clientRoot, 'assets');
  await Directory(assetsDir).create(recursive: true);
  final packPath = p.join(assetsDir, kLynxPackFileName);
  await writeLynxGamePack(projectRoot: projectRoot, outputFilePath: packPath);
  await _ensurePubspecPackAsset(clientRoot);

  onLog?.call('Копирование libengine.so…');
  final soErr = await _stageAndroidEngineSo(
    clientRoot: clientRoot,
    engineLibraryAbsolutePath: engineLibraryAbsolutePath,
    projectRoot: projectRoot,
    onLog: onLog,
  );
  if (soErr != null) return soErr;

  onLog?.call('flutter pub get…');
  var code = await _runCmd(
    'flutter',
    ['pub', 'get'],
    clientRoot,
    onLog,
    env: androidEnv?.toProcessEnv(),
  );
  if (code != 0) return 'flutter pub get завершился с ошибкой ($code)';

  onLog?.call('Сборка APK (это может занять несколько минут)…');
  code = await _runCmd(
    'flutter',
    ['build', 'apk', '-t', 'lib/main_player.dart', '--release'],
    clientRoot,
    onLog,
    env: androidEnv?.toProcessEnv(),
  );
  if (code != 0) {
    return 'flutter build apk не удался (код $code). '
        'Нужны Android SDK, NDK и JAVA. См. engine/scripts/build-apk.ps1';
  }

  final apkBuilt = p.join(
    clientRoot,
    'build',
    'app',
    'outputs',
    'flutter-apk',
    'app-release.apk',
  );
  if (!await File(apkBuilt).exists()) {
    return 'APK не найден после сборки: $apkBuilt';
  }

  final apkOut = p.join(outputDirectory, '$safeName.apk');
  await File(apkBuilt).copy(apkOut);
  await File(p.join(outputDirectory, 'README_BUILD.txt')).writeAsString(
    'Lynx Player — Android\n'
    'APK: $apkOut\n'
    'Установите на устройство или эмулятор.\n',
  );

  onLog?.call('Готово: $apkOut');
  return null;
}

/// Экспорт + полная сборка для выбранного пресета.
Future<String?> runLynxFullBuild({
  required String projectRoot,
  required String outputDirectory,
  required LynxExportPreset preset,
  String? engineLibraryAbsolutePath,
  LynxBuildLog? onLog,
}) async {
  switch (preset) {
    case LynxExportPreset.windows:
      return buildWindowsGameRelease(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
        onLog: onLog,
      );
    case LynxExportPreset.android:
      return buildAndroidGameRelease(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
        onLog: onLog,
      );
    case LynxExportPreset.web:
      return runLynxExport(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        preset: preset,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
        clientRootForWebStaging: await resolveLynxClientRoot(
          projectRoot: projectRoot,
        ),
      );
    case LynxExportPreset.dataBundle:
      return runLynxExport(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        preset: preset,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
      );
    case LynxExportPreset.cart:
      return runLynxExport(
        projectRoot: projectRoot,
        outputDirectory: outputDirectory,
        preset: preset,
        engineLibraryAbsolutePath: engineLibraryAbsolutePath,
      );
  }
}

Future<String?> _stageAndroidEngineSo({
  required String clientRoot,
  required String? engineLibraryAbsolutePath,
  required String projectRoot,
  LynxBuildLog? onLog,
}) async {
  final jniDir = p.join(
    clientRoot,
    'android',
    'app',
    'src',
    'main',
    'jniLibs',
    'arm64-v8a',
  );
  await Directory(jniDir).create(recursive: true);
  final dest = p.join(jniDir, 'libengine.so');

  final existing = File(dest);
  if (await existing.exists() && await existing.length() > 1000) {
    onLog?.call('Используем jniLibs/libengine.so из client');
    return null;
  }

  final bundled = await resolveBundledAndroidEngineSo();
  if (bundled != null) {
    await File(bundled).copy(dest);
    onLog?.call('libengine.so (встроенный) → jniLibs');
    return null;
  }

  final candidates = <String>[];
  if (engineLibraryAbsolutePath != null &&
      engineLibraryAbsolutePath.endsWith('.so')) {
    candidates.add(engineLibraryAbsolutePath);
  }

  final repo = resolveLynxRepoRootFromClient();
  final androidEnv = await loadLynxAndroidEnv();
  candidates.addAll([
    p.join(repo, 'engine', 'target', 'aarch64-linux-android', 'release', 'libengine.so'),
    p.join(repo, 'client', 'android', 'app', 'src', 'main', 'jniLibs', 'arm64-v8a', 'libengine.so'),
    p.join(clientRoot, 'android', 'app', 'src', 'main', 'jniLibs', 'arm64-v8a', 'libengine.so'),
  ]);

  for (final c in candidates) {
    final f = File(c);
    if (await f.exists()) {
      await f.copy(dest);
      onLog?.call('libengine.so → jniLibs');
      return null;
    }
  }

  if (Platform.isWindows && androidEnv?.ndkHome != null) {
    onLog?.call('Сборка libengine.so (cargo-ndk)…');
    final engineRoot = p.join(repo, 'engine');
    final jniOut = p.join(clientRoot, 'android', 'app', 'src', 'main', 'jniLibs');
    if (await File(p.join(engineRoot, 'Cargo.toml')).exists()) {
      if (!await _hasCargoNdk(onLog)) {
        await _runCmd('cargo', ['install', 'cargo-ndk', '--locked'], engineRoot, onLog,
            env: androidEnv?.toProcessEnv());
      }
      await _runCmd(
        'rustup',
        ['target', 'add', 'aarch64-linux-android'],
        engineRoot,
        onLog,
        env: androidEnv?.toProcessEnv(),
      );
      await _runCmd(
        'cargo',
        ['ndk', '-t', 'arm64-v8a', '-P', '24', '-o', jniOut, 'build', '--release'],
        engineRoot,
        onLog,
        env: androidEnv?.toProcessEnv(),
      );
      if (await File(dest).exists()) return null;
    }
  }

  return 'Нет libengine.so. Переустановите Lynx или соберите из репозитория с Rust.';
}

Future<void> _ensurePubspecPackAsset(String clientRoot) async {
  final pubspec = File(p.join(clientRoot, 'pubspec.yaml'));
  if (!await pubspec.exists()) return;
  var text = await pubspec.readAsString();
  const needle = 'assets/lynx_game_data.lynxpack';
  if (text.contains(needle)) return;
  const block = '    - assets/lynx_game_data.lynxpack\n';
  final assetsIdx = text.indexOf('assets:');
  if (assetsIdx < 0) return;
  final insertAt = text.indexOf('\n', assetsIdx) + 1;
  text = text.substring(0, insertAt) + block + text.substring(insertAt);
  await pubspec.writeAsString(text);
}

Future<bool> _hasCargoNdk(LynxBuildLog? onLog) async {
  final r = await Process.run('cargo', ['ndk', '--version'], runInShell: true);
  return r.exitCode == 0;
}

Future<int> _runCmd(
  String executable,
  List<String> args,
  String workDir,
  LynxBuildLog? onLog, {
  Map<String, String>? env,
}) async {
  onLog?.call('> $executable ${args.join(' ')}');
  final result = await Process.run(
    executable,
    args,
    workingDirectory: workDir,
    runInShell: true,
    environment: env ?? Platform.environment,
  );
  final out = '${result.stdout}'.trim();
  final err = '${result.stderr}'.trim();
  if (out.isNotEmpty) onLog?.call(out);
  if (err.isNotEmpty) onLog?.call(err);
  return result.exitCode;
}

Future<void> _copyTree(String source, String dest) async {
  final src = Directory(source);
  if (!await src.exists()) return;
  await Directory(dest).create(recursive: true);
  await for (final entity in src.list(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: source);
    final target = p.join(dest, rel);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
    }
  }
}

Future<void> _copyEngineBin(String? engineLibraryAbsolutePath, String outputDirectory) async {
  if (engineLibraryAbsolutePath == null || engineLibraryAbsolutePath.isEmpty) {
    return;
  }
  final lib = File(engineLibraryAbsolutePath);
  if (!await lib.exists()) return;
  final binDir = Directory(p.join(outputDirectory, 'bin'));
  await binDir.create(recursive: true);
  final name = Platform.isWindows ? 'engine.dll' : p.basename(engineLibraryAbsolutePath);
  await lib.copy(p.join(binDir.path, name));
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
