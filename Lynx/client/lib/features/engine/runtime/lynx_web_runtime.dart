/// Web Player runtime (волна 11b / 18 / Phase IV E25).
enum LynxWebRuntime {
  /// [WebSceneEngine] + упрощённый Lua-подмножество (волна 4).
  webSceneEngine,

  /// Lynx Cart Web: Fengari Lua + logic grids (E18b).
  lynxCartRuntime,

  /// E25a — Lynx Core WASM (`lynx_core.wasm` + `lynx_wasm_core.js`).
  wasmCore,
}

extension LynxWebRuntimeJson on LynxWebRuntime {
  String get jsonValue => switch (this) {
        LynxWebRuntime.webSceneEngine => 'web_scene_engine',
        LynxWebRuntime.lynxCartRuntime => 'lynx_cart_runtime',
        LynxWebRuntime.wasmCore => 'wasm_core',
      };

  static LynxWebRuntime fromJson(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'lynx_cart_runtime':
      case 'wasm_cart':
        return LynxWebRuntime.lynxCartRuntime;
      case 'wasm_core':
      case 'lynx_wasm_core':
      case 'wasm':
        return LynxWebRuntime.wasmCore;
      case 'wasm_core_stub':
        return LynxWebRuntime.wasmCore;
      case 'web_scene_engine':
      case 'web':
      case null:
      case '':
        return LynxWebRuntime.webSceneEngine;
      default:
        return LynxWebRuntime.webSceneEngine;
    }
  }
}
