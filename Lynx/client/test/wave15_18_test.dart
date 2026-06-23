import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:client/features/engine/runtime/lynx_cart_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('LynxCartManifest roundtrip', () {
    final m = LynxCartManifest(
      title: 'Test',
      tags: const ['arcade'],
      tier: 'free_to_play',
    );
    final back = LynxCartManifest.fromJson(m.toJson());
    expect(back.title, 'Test');
    expect(back.tier, 'free_to_play');
    expect(back.tags, ['arcade']);
  });

  test('pack and read lynx-tetris cart', () async {
    final root = p.normalize(p.join(Directory.current.path, '..', 'projects', 'lynx-tetris'));
    if (!await Directory(root).exists()) {
      return;
    }
    final tmp = await Directory.systemTemp.createTemp('lynx_cart_test_');
    final out = p.join(tmp.path, 'tetris.lynxcart');
    final file = await packProjectToLynxCart(projectRoot: root, outputPath: out);
    expect(await file.exists(), isTrue);
    final manifest = await readLynxCartManifest(file.path);
    expect(manifest.title, isNotEmpty);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final cartJson = archive.files.firstWhere((f) => f.name == 'cart.json');
    final json = jsonDecode(utf8.decode(cartJson.content as List<int>)) as Map<String, dynamic>;
    expect(json['format'], 'lynx_cart');
  });
}
