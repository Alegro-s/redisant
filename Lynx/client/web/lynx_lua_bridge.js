/// Fengari Lua bridge for Lynx Cart Web runtime (wave 18 / E18b).
(function () {
  if (typeof fengari === 'undefined') {
    console.warn('LynxLuaBridge: fengari not loaded');
    return;
  }

  const states = new Map();

  function pushNumber(L, f, v) {
    f.lua.lua_pushnumber(L, v);
  }

  function pushBool(L, f, v) {
    f.lua.lua_pushboolean(L, v ? 1 : 0);
  }

  function pushString(L, f, s) {
    f.lua.lua_pushstring(L, s == null ? '' : String(s));
  }

  function toInt(L, f, idx) {
    return f.lua.lua_tointeger(L, idx) | 0;
  }

  function registerGridApi(L, f, api) {
    const push = (fn) => {
      f.lua.lua_pushcfunction(L, fn);
      return 1;
    };

    f.lua.lua_pushcfunction(L, (L) => {
      const name = f.lua.lua_tostring(L, 1);
      const w = toInt(L, f, 2);
      const h = toInt(L, f, 3);
      api.gridEnsure(name, w, h);
      return 0;
    });
    f.lua.lua_setglobal(L, 'grid_ensure');

    f.lua.lua_pushcfunction(L, (L) => {
      const name = f.lua.lua_tostring(L, 1);
      const x = toInt(L, f, 2);
      const y = toInt(L, f, 3);
      pushNumber(L, f, api.gridGet(name, x, y));
      return 1;
    });
    f.lua.lua_setglobal(L, 'grid_get');

    f.lua.lua_pushcfunction(L, (L) => {
      const name = f.lua.lua_tostring(L, 1);
      const x = toInt(L, f, 2);
      const y = toInt(L, f, 3);
      const v = toInt(L, f, 4);
      api.gridSet(name, x, y, v);
      return 0;
    });
    f.lua.lua_setglobal(L, 'grid_set');

    f.lua.lua_pushcfunction(L, (L) => {
      const name = f.lua.lua_tostring(L, 1);
      const v = toInt(L, f, 2);
      api.gridFill(name, v);
      return 0;
    });
    f.lua.lua_setglobal(L, 'grid_fill');

    f.lua.lua_pushcfunction(L, (L) => {
      const name = f.lua.lua_tostring(L, 1);
      pushNumber(L, f, api.gridWidth(name));
      return 1;
    });
    f.lua.lua_setglobal(L, 'grid_width');

    f.lua.lua_pushcfunction(L, (L) => {
      const key = f.lua.lua_tostring(L, 1);
      pushBool(L, f, api.btnPressed(key));
      return 1;
    });
    f.lua.lua_setglobal(L, 'btn_pressed');

    f.lua.lua_pushcfunction(L, (L) => {
      const key = f.lua.lua_tostring(L, 1);
      pushBool(L, f, api.actionPressed(key));
      return 1;
    });
    f.lua.lua_setglobal(L, 'action_pressed');

    f.lua.lua_pushcfunction(L, (L) => {
      const msg = f.lua.lua_tostring(L, 1);
      api.nexusLog(msg);
      return 0;
    });
    f.lua.lua_setglobal(L, 'nexus_log');
  }

  function ticBtnHeld(api, id) {
    switch (id | 0) {
      case 0: return api.keyHeld('left');
      case 1: return api.keyHeld('right');
      case 2: return api.keyHeld('up');
      case 3: return api.keyHeld('down');
      case 4: return api.keyHeld('space') || api.keyHeld('gp_a');
      case 5: return api.keyHeld('gp_b');
      default: return false;
    }
  }

  function ticBtnPressed(api, id) {
    switch (id | 0) {
      case 0: return api.btnPressed('left');
      case 1: return api.btnPressed('right');
      case 2: return api.btnPressed('up');
      case 3: return api.btnPressed('down');
      case 4: return api.btnPressed('space') || api.btnPressed('gp_a');
      case 5: return api.btnPressed('gp_b');
      default: return false;
    }
  }

  function blitSprite(api, id, dx, dy, sw, sh, scale, flip, chroma) {
    scale = Math.max(1, scale | 0);
    sw = sw || 8;
    sh = sh || 8;
    const col = ((id | 0) % 16);
    const row = Math.floor((id | 0) / 16);
    const sx0 = col * 8;
    const sy0 = row * 8;
    for (let py = 0; py < sh * scale; py++) {
      for (let px = 0; px < sw * scale; px++) {
        let bx = sx0 + Math.floor(px / scale);
        let by = sy0 + Math.floor(py / scale);
        if (flip & 1) bx = sx0 + sw - 1 - Math.floor(px / scale);
        if (flip & 2) by = sy0 + sh - 1 - Math.floor(py / scale);
        const c = api.gridGet('tic_bank', bx, by);
        if (c <= 0 || (chroma >= 0 && c === chroma)) continue;
        api.gridSet('display', dx + px, dy + py, c);
      }
    }
  }

  function registerTicApi(L, f, api) {
    api.gridEnsure('display', 240, 136);
    api.gridEnsure('tic_bank', 128, 128);
    api.gridEnsure('tic_map', 240, 136);

    f.lua.lua_pushcfunction(L, (L) => {
      const color = f.lua.lua_gettop(L) >= 1 ? toInt(L, f, 1) : 0;
      api.gridFill('display', color);
      return 0;
    });
    f.lua.lua_setglobal(L, 'cls');

    f.lua.lua_pushcfunction(L, (L) => {
      const x = toInt(L, f, 1);
      const y = toInt(L, f, 2);
      if (f.lua.lua_gettop(L) >= 3) {
        api.gridSet('display', x, y, toInt(L, f, 3));
        return 0;
      }
      pushNumber(L, f, api.gridGet('display', x, y));
      return 1;
    });
    f.lua.lua_setglobal(L, 'pix');

    f.lua.lua_pushcfunction(L, (L) => {
      const id = toInt(L, f, 1);
      const x = toInt(L, f, 2);
      const y = toInt(L, f, 3);
      const chroma = f.lua.lua_gettop(L) >= 4 ? toInt(L, f, 4) : -1;
      const sw = f.lua.lua_gettop(L) >= 7 ? toInt(L, f, 7) : 8;
      const sh = f.lua.lua_gettop(L) >= 8 ? toInt(L, f, 8) : 8;
      const scale = f.lua.lua_gettop(L) >= 9 ? toInt(L, f, 9) : 1;
      const flip = f.lua.lua_gettop(L) >= 10 ? toInt(L, f, 10) : 0;
      blitSprite(api, id, x, y, sw, sh, scale, flip, chroma);
      return 0;
    });
    f.lua.lua_setglobal(L, 'spr');

    f.lua.lua_pushcfunction(L, (L) => {
      const mx = toInt(L, f, 1);
      const my = toInt(L, f, 2);
      const mw = f.lua.lua_gettop(L) >= 3 ? toInt(L, f, 3) : 240;
      const mh = f.lua.lua_gettop(L) >= 4 ? toInt(L, f, 4) : 136;
      const sx = f.lua.lua_gettop(L) >= 5 ? toInt(L, f, 5) : 0;
      const sy = f.lua.lua_gettop(L) >= 6 ? toInt(L, f, 6) : 0;
      const scale = f.lua.lua_gettop(L) >= 7 ? toInt(L, f, 7) : 1;
      for (let ty = 0; ty < mh; ty++) {
        for (let tx = 0; tx < mw; tx++) {
          const tile = api.gridGet('tic_map', mx + tx, my + ty);
          if (tile > 0) {
            blitSprite(api, tile, sx + tx * 8 * scale, sy + ty * 8 * scale, 8, 8, scale, 0, -1);
          }
        }
      }
      return 0;
    });
    f.lua.lua_setglobal(L, 'map');

    f.lua.lua_pushcfunction(L, (L) => {
      pushBool(L, f, ticBtnHeld(api, toInt(L, f, 1)));
      return 1;
    });
    f.lua.lua_setglobal(L, 'btn');

    f.lua.lua_pushcfunction(L, (L) => {
      pushBool(L, f, ticBtnPressed(api, toInt(L, f, 1)));
      return 1;
    });
    f.lua.lua_setglobal(L, 'btnp');

    f.lua.lua_pushcfunction(L, (L) => {
      const id = toInt(L, f, 1);
      const note = f.lua.lua_gettop(L) >= 2 ? toInt(L, f, 2) : -1;
      const duration = f.lua.lua_gettop(L) >= 3 ? toInt(L, f, 3) : -1;
      const channel = f.lua.lua_gettop(L) >= 4 ? toInt(L, f, 4) : -1;
      const volume = f.lua.lua_gettop(L) >= 5 ? toInt(L, f, 5) : 15;
      const speed = f.lua.lua_gettop(L) >= 6 ? toInt(L, f, 6) : 0;
      api.ticSfx(id, note, duration, channel, volume, speed);
      return 0;
    });
    f.lua.lua_setglobal(L, 'sfx');

    f.lua.lua_pushcfunction(L, (L) => {
      const track = toInt(L, f, 1);
      const frame = f.lua.lua_gettop(L) >= 2 ? toInt(L, f, 2) : -1;
      const row = f.lua.lua_gettop(L) >= 3 ? toInt(L, f, 3) : -1;
      const loopOn = f.lua.lua_gettop(L) >= 4 ? f.lua.lua_toboolean(L, 4) : true;
      api.ticMusic(track, frame, row, loopOn);
      return 0;
    });
    f.lua.lua_setglobal(L, 'music');
  }

  window.LynxLuaBridge = {
    create(stateId, gridApi) {
      const f = fengari;
      const L = f.lauxlib.luaL_newstate();
      f.lualib.luaL_openlibs(L);
      registerGridApi(L, f, gridApi);
      registerTicApi(L, f, gridApi);
      states.set(stateId, { L, f, code: null, loaded: false, hasTic: false, hasBoot: false, booted: false });
    },

    load(stateId, code) {
      const st = states.get(stateId);
      if (!st) return 'no state';
      const f = st.f;
      const L = st.L;
      const status = f.lauxlib.luaL_loadstring(L, code);
      if (status !== f.lua.LUA_OK) {
        const err = f.lua.lua_tostring(L, -1);
        f.lua.lua_pop(L, 1);
        return err || 'load error';
      }
      const run = f.lua.lua_pcall(L, 0, 0, 0);
      if (run !== f.lua.LUA_OK) {
        const err = f.lua.lua_tostring(L, -1);
        f.lua.lua_pop(L, 1);
        return err || 'boot error';
      }
      st.loaded = true;
      st.code = code;
      f.lua.lua_getglobal(L, 'TIC');
      st.hasTic = f.lua.lua_type(L, -1) === f.lua.LUA_TFUNCTION;
      f.lua.lua_pop(L, 1);
      f.lua.lua_getglobal(L, 'BOOT');
      st.hasBoot = f.lua.lua_type(L, -1) === f.lua.LUA_TFUNCTION;
      f.lua.lua_pop(L, 1);
      st.booted = !st.hasBoot;
      return null;
    },

    runFrame(stateId, dt, globals) {
      const st = states.get(stateId);
      if (!st || !st.code) return 'not loaded';
      const f = st.f;
      const L = st.L;
      pushNumber(L, f, dt);
      f.lua.lua_setglobal(L, 'dt');
      for (const [k, v] of Object.entries(globals || {})) {
        if (typeof v === 'boolean') {
          pushBool(L, f, v);
        } else if (typeof v === 'number') {
          pushNumber(L, f, v);
        } else {
          pushString(L, f, v);
        }
        f.lua.lua_setglobal(L, k);
      }
      if (!st.booted && st.hasBoot) {
        f.lua.lua_getglobal(L, 'BOOT');
        const boot = f.lua.lua_pcall(L, 0, 0, 0);
        if (boot !== f.lua.LUA_OK) {
          const err = f.lua.lua_tostring(L, -1);
          f.lua.lua_pop(L, 1);
          return err || 'BOOT error';
        }
        st.booted = true;
      }
      if (st.hasTic) {
        f.lua.lua_getglobal(L, 'TIC');
        const call = f.lua.lua_pcall(L, 0, 0, 0);
        if (call !== f.lua.LUA_OK) {
          const err = f.lua.lua_tostring(L, -1);
          f.lua.lua_pop(L, 1);
          return err || 'TIC error';
        }
        return null;
      }
      const status = f.lauxlib.luaL_loadstring(L, st.code);
      if (status !== f.lua.LUA_OK) {
        return f.lua.lua_tostring(L, -1) || 'load error';
      }
      const call = f.lua.lua_pcall(L, 0, 0, 0);
      if (call !== f.lua.LUA_OK) {
        const err = f.lua.lua_tostring(L, -1);
        f.lua.lua_pop(L, 1);
        return err || 'runtime error';
      }
      return null;
    },

    destroy(stateId) {
      const st = states.get(stateId);
      if (st) {
        st.f.lua.lua_close(st.L);
        states.delete(stateId);
      }
    },
  };
})();
