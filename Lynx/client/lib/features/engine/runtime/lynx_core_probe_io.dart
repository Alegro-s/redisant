import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'play_engine_init.dart';

class LynxCoreProbeResult {
  final String version;
  final int apiVersion;
  const LynxCoreProbeResult({required this.version, required this.apiVersion});
}

typedef _CoreApiVersionC = Uint32 Function();
typedef _CoreApiVersionDart = int Function();
typedef _CoreVersionStringC = Pointer<Utf8> Function();
typedef _CoreVersionStringDart = Pointer<Utf8> Function();
typedef _CoreFreeStringC = Void Function(Pointer<Utf8>);
typedef _CoreFreeStringDart = void Function(Pointer<Utf8>);

Future<LynxCoreProbeResult?> probeInstalledLynxCore() async {
  final libPath = await resolvePlayEngineLibrary();
  if (libPath == null || libPath.isEmpty) return null;
  return probeLynxCoreFromLibrary(libPath);
}

Future<LynxCoreProbeResult?> probeLynxCoreFromLibrary(String libraryPath) async {
  final file = File(libraryPath);
  if (!await file.exists()) return null;
  try {
    final lib = DynamicLibrary.open(file.absolute.path);
    final apiFn = lib
        .lookup<NativeFunction<_CoreApiVersionC>>('lynx_core_api_version')
        .asFunction<_CoreApiVersionDart>();
    final verFn = lib
        .lookup<NativeFunction<_CoreVersionStringC>>('lynx_core_version_string')
        .asFunction<_CoreVersionStringDart>();
    final freeFn = lib
        .lookup<NativeFunction<_CoreFreeStringC>>('core_free_string')
        .asFunction<_CoreFreeStringDart>();
    final ptr = verFn();
    if (ptr == nullptr) return null;
    final version = ptr.toDartString();
    freeFn(ptr);
    if (version.isEmpty) return null;
    return LynxCoreProbeResult(version: version, apiVersion: apiFn());
  } catch (_) {
    return null;
  }
}
