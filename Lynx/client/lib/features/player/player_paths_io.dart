import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/runtime/embedded_game_pack_io.dart';

/// Корень вшитого проекта (`game_data/`) для Lynx Player.
Future<String?> resolvePlayerProjectRoot() async {
  const fromDefine = String.fromEnvironment('LYNX_GAME_DATA', defaultValue: '');
  if (fromDefine.isNotEmpty) {
    final d = Directory(fromDefine);
    if (await d.exists()) return p.normalize(d.absolute.path);
  }

  if (!Platform.isAndroid && !Platform.isIOS) {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final besideExe = Directory(p.join(exeDir, 'game_data'));
    if (await besideExe.exists()) {
      return p.normalize(besideExe.absolute.path);
    }
    final cwd = Directory(p.join(Directory.current.path, 'game_data'));
    if (await cwd.exists()) return p.normalize(cwd.absolute.path);
  }

  final extracted = await ensureEmbeddedGamePackExtracted();
  if (extracted != null) return extracted;

  return null;
}

/// Распаковка `assets/lynx_game_data.lynxpack` (Android/iOS export preset).
Future<String?> ensureEmbeddedGamePackExtracted() async {
  const assetPath = 'assets/lynx_game_data.lynxpack';
  try {
    await rootBundle.load(assetPath);
  } catch (_) {
    return null;
  }

  final doc = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(doc.path, 'lynx_game_data'));
  final marker = File(p.join(root.path, '.lynx_pack_ok'));
  if (await marker.exists()) return root.path;

  final bytes = await rootBundle.load(assetPath);
  await extractLynxPackBytes(bytes.buffer.asUint8List(), root.path);
  await marker.writeAsString('ok');
  return root.path;
}
