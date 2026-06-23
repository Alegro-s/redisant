import 'package:client/features/engine/runtime/tic_audio_engine.dart';
import 'package:client/features/engine/runtime/web_scene_engine.dart';

import 'engine_types_web.dart';

class EngineBridge {
  static int _seq = 0;
  static final Map<int, WebSceneEngine> _scenes = {};

  static void init({String? preferredLibraryPath}) {}

  static SceneHandle sceneCreate() {
    final id = ++_seq;
    _scenes[id] = WebSceneEngine.empty();
    return id;
  }

  static void sceneDestroy(SceneHandle id) {
    if (sceneIsNull(id)) return;
    _scenes.remove(id);
  }

  static void sceneUpdate(SceneHandle id, double dt) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.update(dt);
  }

  static String? sceneToJson(SceneHandle id) {
    if (sceneIsNull(id)) return null;
    return _scenes[id]?.toJsonString();
  }

  static SceneHandle sceneFromJson(String json) {
    try {
      final eng = WebSceneEngine.fromJsonString(json);
      final id = ++_seq;
      _scenes[id] = eng;
      return id;
    } catch (_) {
      return kSceneNull;
    }
  }

  static void sceneSetKey(SceneHandle id, String key, bool pressed) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.setKey(key, pressed);
  }

  static void sceneSetGamepad(SceneHandle id, double lx, double ly, int buttonMask) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.setGamepadMask(buttonMask);
  }

  static int sceneAddEntity(SceneHandle id, String name, double x, double y, double r, double g, double b, double a) {
    return 0;
  }

  static bool sceneSetScript(SceneHandle id, int entityId, String code) => false;

  static void coreFreeString(dynamic _) {}

  static List<String> sceneDrainSounds(SceneHandle id) => const [];

  static List<String> sceneDrainDebugLog(SceneHandle id) => const [];

  static void sceneSetPaused(SceneHandle id, bool paused) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.paused = paused;
  }

  static void sceneSetTimeScale(SceneHandle id, double scale) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.timeScale = scale;
  }

  static String? sceneTakePendingLoad(SceneHandle id) {
    if (sceneIsNull(id)) return null;
    return _scenes[id]?.takePendingLoad();
  }

  static void sceneSetNamedKey(SceneHandle id, String name, bool pressed) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.setNamedKey(name, pressed);
  }

  static void sceneInitCartLua(SceneHandle id, String code) {
    if (sceneIsNull(id)) return;
    _scenes[id]?.initCartLua(code);
  }

  static void sceneSetTicAudio(SceneHandle id, TicAudioEngine? engine) {
    if (sceneIsNull(id)) return;
    final scene = _scenes[id];
    if (scene != null) {
      scene.ticAudio = engine;
    }
  }

  static List<Map<String, dynamic>> sceneDrainBtDebug(SceneHandle id) => const [];

  static void sceneSetBtBreakpoint(SceneHandle id, String subpath) {}

  static void sceneBtDebugStep(SceneHandle id) {}
}
