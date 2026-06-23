import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'engine_binary_loader.dart';

/// Путь к нативной библиотеке движка для Play / Lynx Player (без обязательного API).
Future<String?> resolvePlayEngineLibrary({Dio? http}) async {
  if (kIsWeb) return null;

  const fromDefine = String.fromEnvironment('LYNX_ENGINE_LIB', defaultValue: '');
  if (fromDefine.isNotEmpty) {
    final f = File(fromDefine);
    if (await f.exists()) return f.absolute.path;
  }

  final bundled = await findBundledEngineLibrary();
  if (bundled != null) return bundled;

  final cached = await getLastCachedEngineLibraryPath();
  if (cached != null) return cached;

  final installed = await resolveLatestInstalledEngineLibrary();
  if (installed != null) return installed;

  if (http != null) {
    return ensureEngineBinary(http);
  }
  return null;
}

/// `bin/engine.dll` (или .so) рядом с исполняемым файлом Player.
Future<String?> findBundledEngineLibrary() async {
  if (kIsWeb) return null;
  final names = <String>[
    if (Platform.isWindows) 'engine.dll',
    if (Platform.isLinux) 'libengine.so',
    if (Platform.isMacOS) 'libengine.dylib',
    if (Platform.isAndroid) 'libengine.so',
  ];
  if (names.isEmpty) return null;

  final exeDir = p.dirname(Platform.resolvedExecutable);
  for (final name in names) {
    final inBin = File(p.join(exeDir, 'bin', name));
    if (await inBin.exists()) return inBin.absolute.path;
    final flat = File(p.join(exeDir, name));
    if (await flat.exists()) return flat.absolute.path;
  }
  return null;
}
