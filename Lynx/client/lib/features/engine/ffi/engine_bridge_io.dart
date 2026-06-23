import 'dart:convert' as convert;
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'engine_types_io.dart';

typedef SceneCreateC = Pointer<Void> Function();
typedef SceneCreateDart = Pointer<Void> Function();
typedef SceneDestroyC = Void Function(Pointer<Void>);
typedef SceneDestroyDart = void Function(Pointer<Void>);
typedef SceneAddEntityC =
    Uint64 Function(
      Pointer<Void>,
      Pointer<Utf8>,
      Float,
      Float,
      Float,
      Float,
      Float,
      Float,
    );
typedef SceneAddEntityDart =
    int Function(
      Pointer<Void>,
      Pointer<Utf8>,
      double,
      double,
      double,
      double,
      double,
      double,
    );
typedef SceneSetScriptC = Uint8 Function(Pointer<Void>, Uint64, Pointer<Utf8>);
typedef SceneSetScriptDart = int Function(Pointer<Void>, int, Pointer<Utf8>);
typedef SceneUpdateC = Void Function(Pointer<Void>, Float);
typedef SceneUpdateDart = void Function(Pointer<Void>, double);
typedef SceneToJsonC = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneToJsonDart = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneFromJsonC = Pointer<Void> Function(Pointer<Utf8>);
typedef SceneFromJsonDart = Pointer<Void> Function(Pointer<Utf8>);
typedef SceneSetKeyC = Void Function(Pointer<Void>, Uint8, Bool);
typedef SceneSetKeyDart = void Function(Pointer<Void>, int, bool);
typedef SceneSetGamepadC = Void Function(Pointer<Void>, Float, Float, Uint32);
typedef SceneSetGamepadDart = void Function(Pointer<Void>, double, double, int);
typedef CoreFreeStringC = Void Function(Pointer<Utf8>);
typedef CoreFreeStringDart = void Function(Pointer<Utf8>);
typedef SceneDrainJsonC = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneDrainJsonDart = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneSetPausedC = Void Function(Pointer<Void>, Bool);
typedef SceneSetPausedDart = void Function(Pointer<Void>, bool);
typedef SceneSetTimeScaleC = Void Function(Pointer<Void>, Float);
typedef SceneSetTimeScaleDart = void Function(Pointer<Void>, double);
typedef SceneTakePendingLoadC = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneTakePendingLoadDart = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneSetNamedKeyC = Void Function(Pointer<Void>, Pointer<Utf8>, Bool);
typedef SceneSetNamedKeyDart = void Function(Pointer<Void>, Pointer<Utf8>, bool);
typedef SceneDrainBtDebugC = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneDrainBtDebugDart = Pointer<Utf8> Function(Pointer<Void>);
typedef SceneSetBtBreakpointC = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef SceneSetBtBreakpointDart = void Function(Pointer<Void>, Pointer<Utf8>);
typedef SceneBtDebugStepC = Void Function(Pointer<Void>);
typedef SceneBtDebugStepDart = void Function(Pointer<Void>);

List<String> _installedEngineLibraryCandidates() {
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null || local.isEmpty) return const [];
  final root = Directory(p.join(local, 'Lynx', 'engines'));
  if (!root.existsSync()) return const [];

  final versions = root
      .listSync()
      .whereType<Directory>()
      .map((d) => p.basename(d.path))
      .toList()
    ..sort((a, b) => b.compareTo(a));

  final out = <String>[];
  for (final version in versions) {
    out.add(p.join(root.path, version, 'windows', 'engine.dll'));
  }
  return out;
}

class EngineBridge {
  static late DynamicLibrary _lib;

  static DynamicLibrary get lib => _lib;

  static void init({String? preferredLibraryPath}) {
    if (preferredLibraryPath != null && preferredLibraryPath.isNotEmpty) {
      final f = File(preferredLibraryPath);
      if (f.existsSync()) {
        _lib = DynamicLibrary.open(f.absolute.path);
        return;
      }
    }
    if (Platform.isWindows) {
      final possiblePaths = [
        '../engine/target/release/engine.dll',
        'engine/target/release/engine.dll',
        'engine.dll',
        r'..\engine\target\release\engine.dll',
        ..._installedEngineLibraryCandidates(),
      ];
      String? foundPath;
      for (final path in possiblePaths) {
        if (File(path).existsSync()) {
          foundPath = path;
          break;
        }
      }
      if (foundPath == null) {
        throw Exception(
          'Could not find engine.dll. Импортируйте Lynx Engine (.lynxengine) в Hub.',
        );
      }
      _lib = DynamicLibrary.open(foundPath);
    } else if (Platform.isLinux) {
      final dev = '../engine/target/release/libengine.so';
      if (File(dev).existsSync()) {
        _lib = DynamicLibrary.open(dev);
      } else {
        throw Exception('Could not find libengine.so');
      }
    } else if (Platform.isMacOS) {
      final dev = '../engine/target/release/libengine.dylib';
      if (File(dev).existsSync()) {
        _lib = DynamicLibrary.open(dev);
      } else {
        throw Exception('Could not find libengine.dylib');
      }
    } else if (Platform.isAndroid) {
      if (preferredLibraryPath != null && preferredLibraryPath.isNotEmpty) {
        final f = File(preferredLibraryPath);
        if (f.existsSync()) {
          _lib = DynamicLibrary.open(f.absolute.path);
          return;
        }
      }
      try {
        _lib = DynamicLibrary.open('libengine.so');
        return;
      } catch (_) {
        
      }
      throw Exception(
        'Android: нет libengine.so. Соберите APK из каталога engine: scripts/build-apk.ps1 / build-apk.sh, '
        'либо загрузите артефакт с API /engine/manifest.',
      );
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  static SceneHandle sceneCreate() {
    final create = _lib
        .lookup<NativeFunction<SceneCreateC>>('scene_create')
        .asFunction<SceneCreateDart>();
    return create();
  }

  static void sceneDestroy(SceneHandle ptr) {
    if (sceneIsNull(ptr)) return;
    final destroy = _lib
        .lookup<NativeFunction<SceneDestroyC>>('scene_destroy')
        .asFunction<SceneDestroyDart>();
    destroy(ptr);
  }

  static int sceneAddEntity(
    SceneHandle scene,
    String name,
    double x,
    double y,
    double r,
    double g,
    double b,
    double a,
  ) {
    final add = _lib
        .lookup<NativeFunction<SceneAddEntityC>>('scene_add_entity')
        .asFunction<SceneAddEntityDart>();
    final namePtr = name.toNativeUtf8();
    try {
      return add(scene, namePtr, x, y, r, g, b, a);
    } finally {
      calloc.free(namePtr);
    }
  }

  static bool sceneSetScript(SceneHandle scene, int id, String code) {
    final setScript = _lib
        .lookup<NativeFunction<SceneSetScriptC>>('scene_set_script')
        .asFunction<SceneSetScriptDart>();
    final codePtr = code.toNativeUtf8();
    try {
      return setScript(scene, id, codePtr) == 1;
    } finally {
      calloc.free(codePtr);
    }
  }

  static void sceneUpdate(SceneHandle scene, double dt) {
    final update = _lib
        .lookup<NativeFunction<SceneUpdateC>>('scene_update')
        .asFunction<SceneUpdateDart>();
    update(scene, dt);
  }

  static String? sceneToJson(SceneHandle scene) {
    if (sceneIsNull(scene)) return null;
    final toJson = _lib
        .lookup<NativeFunction<SceneToJsonC>>('scene_to_json')
        .asFunction<SceneToJsonDart>();
    final ptr = toJson(scene);
    if (ptr == nullptr) return null;
    final str = ptr.toDartString();
    coreFreeString(ptr);
    return str;
  }

  static SceneHandle sceneFromJson(String json) {
    final fromJson = _lib
        .lookup<NativeFunction<SceneFromJsonC>>('scene_from_json')
        .asFunction<SceneFromJsonDart>();
    final jsonPtr = json.toNativeUtf8();
    try {
      final p = fromJson(jsonPtr);
      if (p == nullptr) return kSceneNull;
      return p;
    } finally {
      calloc.free(jsonPtr);
    }
  }

  static void sceneSetKey(SceneHandle scene, String key, bool pressed) {
    if (sceneIsNull(scene)) return;
    final setKey = _lib
        .lookup<NativeFunction<SceneSetKeyC>>('scene_set_key')
        .asFunction<SceneSetKeyDart>();
    final keyCode = key.codeUnitAt(0);
    setKey(scene, keyCode, pressed);
  }

  static void sceneSetGamepad(
    SceneHandle scene,
    double lx,
    double ly,
    int buttonMask,
  ) {
    if (sceneIsNull(scene)) return;
    try {
      final f = _lib
          .lookup<NativeFunction<SceneSetGamepadC>>('scene_set_gamepad')
          .asFunction<SceneSetGamepadDart>();
      f(scene, lx, ly, buttonMask);
    } catch (_) {}
  }

  static void coreFreeString(Pointer<Utf8> ptr) {
    final free = _lib
        .lookup<NativeFunction<CoreFreeStringC>>('core_free_string')
        .asFunction<CoreFreeStringDart>();
    free(ptr);
  }

  static List<String> sceneDrainSounds(SceneHandle scene) {
    if (sceneIsNull(scene)) return [];
    final drain = _lib
        .lookup<NativeFunction<SceneDrainJsonC>>('scene_drain_sounds')
        .asFunction<SceneDrainJsonDart>();
    final ptr = drain(scene);
    if (ptr == nullptr) return [];
    try {
      final str = ptr.toDartString();
      final list = convert.jsonDecode(str);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {
    } finally {
      coreFreeString(ptr);
    }
    return [];
  }

  static void sceneSetPaused(SceneHandle scene, bool paused) {
    if (sceneIsNull(scene)) return;
    try {
      final f = _lib
          .lookup<NativeFunction<SceneSetPausedC>>('scene_set_paused')
          .asFunction<SceneSetPausedDart>();
      f(scene, paused);
    } catch (_) {}
  }

  static void sceneSetTimeScale(SceneHandle scene, double scale) {
    if (sceneIsNull(scene)) return;
    try {
      final f = _lib
          .lookup<NativeFunction<SceneSetTimeScaleC>>('scene_set_time_scale')
          .asFunction<SceneSetTimeScaleDart>();
      f(scene, scale);
    } catch (_) {}
  }

  static String? sceneTakePendingLoad(SceneHandle scene) {
    if (sceneIsNull(scene)) return null;
    try {
      final take = _lib
          .lookup<NativeFunction<SceneTakePendingLoadC>>('scene_take_pending_load')
          .asFunction<SceneTakePendingLoadDart>();
      final ptr = take(scene);
      if (ptr == nullptr) return null;
      try {
        return ptr.toDartString();
      } finally {
        coreFreeString(ptr);
      }
    } catch (_) {
      return null;
    }
  }

  static void sceneSetNamedKey(SceneHandle scene, String name, bool pressed) {
    if (sceneIsNull(scene)) return;
    try {
      final f = _lib
          .lookup<NativeFunction<SceneSetNamedKeyC>>('scene_set_named_key')
          .asFunction<SceneSetNamedKeyDart>();
      final namePtr = name.toNativeUtf8();
      try {
        f(scene, namePtr, pressed);
      } finally {
        calloc.free(namePtr);
      }
    } catch (_) {}
  }

  static List<String> sceneDrainDebugLog(SceneHandle scene) {
    if (sceneIsNull(scene)) return [];
    final drain = _lib
        .lookup<NativeFunction<SceneDrainJsonC>>('scene_drain_debug_log')
        .asFunction<SceneDrainJsonDart>();
    final ptr = drain(scene);
    if (ptr == nullptr) return [];
    try {
      final str = ptr.toDartString();
      final list = convert.jsonDecode(str);
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    } catch (_) {
    } finally {
      coreFreeString(ptr);
    }
    return [];
  }

  static List<Map<String, dynamic>> sceneDrainBtDebug(SceneHandle scene) {
    if (sceneIsNull(scene)) return [];
    try {
      final drain = _lib
          .lookup<NativeFunction<SceneDrainBtDebugC>>('scene_drain_bt_debug_json')
          .asFunction<SceneDrainBtDebugDart>();
      final ptr = drain(scene);
      if (ptr == nullptr) return [];
      try {
        final str = ptr.toDartString();
        final list = convert.jsonDecode(str);
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } finally {
        coreFreeString(ptr);
      }
    } catch (_) {}
    return [];
  }

  static void sceneSetBtBreakpoint(SceneHandle scene, String subpath) {
    if (sceneIsNull(scene)) return;
    try {
      final f = _lib
          .lookup<NativeFunction<SceneSetBtBreakpointC>>('scene_set_bt_breakpoint')
          .asFunction<SceneSetBtBreakpointDart>();
      final ptr = subpath.toNativeUtf8();
      try {
        f(scene, ptr);
      } finally {
        calloc.free(ptr);
      }
    } catch (_) {}
  }

  static void sceneInitCartLua(SceneHandle scene, String code) {}

  static void sceneSetTicAudio(SceneHandle scene, Object? engine) {}

  static void sceneBtDebugStep(SceneHandle scene) {
    if (sceneIsNull(scene)) return;
    try {
      final f = _lib
          .lookup<NativeFunction<SceneBtDebugStepC>>('scene_bt_debug_step')
          .asFunction<SceneBtDebugStepDart>();
      f(scene);
    } catch (_) {}
  }
}
