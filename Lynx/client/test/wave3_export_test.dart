import 'dart:io';

import 'package:client/features/engine/runtime/embedded_game_pack_io.dart';
import 'package:client/features/engine/runtime/lynx_export_io.dart';
import 'package:client/features/engine/runtime/play_engine_init.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final wave2 = p.normalize(
    p.join(Directory.current.path, '..', 'projects', 'platformer-wave2'),
  );
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lynx_export_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) {
      await tmp.delete(recursive: true);
    }
  });

  test('platformer-wave2 exists', () {
    expect(Directory(wave2).existsSync(), isTrue);
  });

  test('export windows preset creates game_data and zip', () async {
    final out = p.join(tmp.path, 'win');
    final err = await runLynxExport(
      projectRoot: wave2,
      outputDirectory: out,
      preset: LynxExportPreset.windows,
    );
    expect(err, isNull);
    expect(Directory(p.join(out, 'windows', 'game_data')).existsSync(), isTrue);
    expect(File(p.join(out, 'windows', 'game_data', 'project.json')).existsSync(), isTrue);
    expect(File(p.join(out, 'README_LYNX_EXPORT.txt')).existsSync(), isTrue);
    final zips = Directory(out)
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('_windows.zip'));
    expect(zips.length, 1);
  });

  test('export android creates lynxpack', () async {
    final out = p.join(tmp.path, 'apk');
    final err = await runLynxExport(
      projectRoot: wave2,
      outputDirectory: out,
      preset: LynxExportPreset.android,
    );
    expect(err, isNull);
    expect(
      File(p.join(out, 'android', kLynxPackFileName)).existsSync(),
      isTrue,
    );
  });

  test('lynx pack round-trip', () async {
    final pack = p.join(tmp.path, 'test.lynxpack');
    await writeLynxGamePack(projectRoot: wave2, outputFilePath: pack);
    final dest = p.join(tmp.path, 'extracted');
    final bytes = await File(pack).readAsBytes();
    await extractLynxPackBytes(bytes, dest);
    expect(File(p.join(dest, 'project.json')).existsSync(), isTrue);
  });

  test('findBundledEngineLibrary returns null without bin', () async {
    expect(await findBundledEngineLibrary(), isNull);
  });
}
