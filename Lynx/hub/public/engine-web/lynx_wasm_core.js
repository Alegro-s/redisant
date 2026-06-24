// E25a — Lynx Core WASM loader (Phase IV).
(function (global) {
  'use strict';

  let modulePromise = null;
  let exports = null;

  async function loadLynxWasmCore(wasmUrl) {
    if (exports) return exports;
    if (!modulePromise) {
      modulePromise = (async () => {
        const url = wasmUrl || 'lynx_core.wasm';
        const resp = await fetch(url);
        if (!resp.ok) throw new Error('lynx_core.wasm not found: ' + url);
        const bytes = await resp.arrayBuffer();
        const { instance } = await WebAssembly.instantiate(bytes, {});
        exports = instance.exports;
        return exports;
      })();
    }
    return modulePromise;
  }

  function readVersion(ex) {
    const ptr = ex.lynx_wasm_core_version_ptr();
    const len = ex.lynx_wasm_core_version_len();
    if (!ptr || !len) return '';
    const mem = new Uint8Array(ex.memory.buffer, ptr, len);
    return new TextDecoder().decode(mem);
  }

  global.LynxWasmCore = {
    load: loadLynxWasmCore,
    init: async (width, height, wasmUrl) => {
      const ex = await loadLynxWasmCore(wasmUrl);
      const ok = ex.lynx_wasm_init(width | 0, height | 0);
      return {
        ok: ok === 1,
        apiVersion: ex.lynx_wasm_core_api_version(),
        version: readVersion(ex),
      };
    },
    tick: async (dt, wasmUrl) => {
      const ex = await loadLynxWasmCore(wasmUrl);
      return ex.lynx_wasm_tick(dt);
    },
  };
})(typeof window !== 'undefined' ? window : globalThis);
