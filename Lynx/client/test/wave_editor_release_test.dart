import 'dart:io';

import 'package:client/features/engine/runtime/embedded_game_pack_io.dart';
import 'package:client/features/engine/runtime/lynx_project_templates.dart';
import 'package:client/features/engine/runtime/play_engine_init.dart';
import 'package:client/features/engine/runtime/project_zip_export_io.dart';
import 'package:client/features/engine/runtime/project_zip_import_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repoRoot = p.normalize(p.join(Directory.current.path, '..'));
  final tetris = p.join(repoRoot, 'projects', 'tetris-demo');
  final platformer = p.join(repoRoot, 'projects', 'platformer-wave2');

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lynx_release_');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('tetris-demo template is present', () {
    expect(Directory(tetris).existsSync(), isTrue);
    expect(File(p.join(tetris, 'project.json')).existsSync(), isTrue);
    expect(File(p.join(tetris, 'assets', 'scripts', 'tetris.lua')).existsSync(), isTrue);
  });

  test('resolveTemplateProjectDirectory finds tetris in dev tree', () {
    final resolved = resolveTemplateProjectDirectory('tetris-demo');
    expect(resolved, isNotNull);
    expect(p.basename(resolved!), equals('tetris-demo'));
  });

  test('.lynxproject pack and import round-trip', () async {
    final zipPath = p.join(tmp.path, 'tetris-demo.$kLynxProjectZipExtension');
    final err = await packProjectDirectoryToZipFile(
      projectRoot: tetris,
      outputZipPath: zipPath,
    );
    expect(err, isNull);
    expect(File(zipPath).existsSync(), isTrue);

    final extractDir = Directory(p.join(tmp.path, 'imported'));
    await extractDir.create(recursive: true);
    final extractErr = await extractZipArchiveToDirectory(
      zipFile: File(zipPath),
      destinationDirectory: extractDir,
    );
    expect(extractErr, isNull);
    final root = await findNexusProjectRoot(extractDir.path);
    expect(root, isNotNull);
    expect(File(p.join(root!, 'project.json')).existsSync(), isTrue);
    expect(File(p.join(root, 'assets', 'scripts', 'tetris.lua')).existsSync(), isTrue);
  });

  test('embedded game pack from tetris-demo', () async {
    final pack = p.join(tmp.path, 'tetris.lynxpack');
    await writeLynxGamePack(projectRoot: tetris, outputFilePath: pack);
    final dest = p.join(tmp.path, 'game_data');
    await extractLynxPackBytes(await File(pack).readAsBytes(), dest);
    expect(File(p.join(dest, 'project.json')).existsSync(), isTrue);
    final json = await File(p.join(dest, 'project.json')).readAsString();
    expect(json, contains('Tetris'));
  });

  test('findBundledEngineLibrary is null in test harness', () async {
    expect(await findBundledEngineLibrary(), isNull);
  });

  test('platformer-wave2 still exports for regression', () async {
    expect(Directory(platformer).existsSync(), isTrue);
    final zipPath = p.join(tmp.path, 'pw2.$kLynxProjectZipExtension');
    expect(
      await packProjectDirectoryToZipFile(projectRoot: platformer, outputZipPath: zipPath),
      isNull,
    );
  });
}
