import 'dart:convert';
import 'dart:math' as math;

import 'lynx_lua_web_export.dart';
import 'tic_audio_engine.dart';
import 'web_input_frame.dart';
import 'web_logic_grid_state.dart';
import 'web_script_runtime.dart';

class WebSceneEngine {
  WebSceneEngine._(this._root);

  final Map<String, dynamic> _root;
  final _KeyState _keys = _KeyState();
  bool paused = false;
  double timeScale = 1.0;
  String? _pendingLoad;

  final WebLogicGridState logicGrids = WebLogicGridState();
  LynxLuaWebRuntime? _luaRuntime;
  TicAudioEngine? ticAudio;
  String? _logicScriptCode;
  double _simAccumulator = 0;
  int _gamepadMask = 0;
  bool cartMode = false;

  void initCartLua(String code) {
    cartMode = true;
    _logicScriptCode = code;
    logicGrids.loadFromScene(
      (_root['logic_grids'] as Map?)?.cast<String, dynamic>(),
    );
    _luaRuntime?.dispose();
    _luaRuntime = LynxLuaWebRuntime.create(logicGrids, ticAudio: ticAudio);
    final err = _luaRuntime?.load(code);
    if (err != null) {
      logicGrids.log('Lua load: $err');
    }
  }

  void setGamepadMask(int mask) {
    _gamepadMask = mask & 0x3F;
  }

  Map<String, Map<String, dynamic>> get logicGridsJson => logicGrids.toSceneJson();

  factory WebSceneEngine.empty() {
    return WebSceneEngine._({
      'entities': <dynamic>[],
      'next_id': 0,
    });
  }

  factory WebSceneEngine.fromJsonString(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return WebSceneEngine._(map);
  }

  List<Map<String, dynamic>> get _entities =>
      List<Map<String, dynamic>>.from(_root['entities'] as List? ?? []);

  set _entities(List<Map<String, dynamic>> v) => _root['entities'] = v;

  String? toJsonString() {
    try {
      return jsonEncode(_root);
    } catch (_) {
      return null;
    }
  }

  void setKey(String key, bool pressed) {
    if (key.isEmpty) return;
    _keys.setKey(key, pressed);
  }

  void setNamedKey(String name, bool pressed) => _keys.setNamed(name, pressed);

  String? takePendingLoad() {
    final next = _pendingLoad;
    _pendingLoad = null;
    return next;
  }

  void update(double dt) {
    if (paused) return;
    dt *= timeScale.clamp(0.0, double.infinity);
    if (cartMode && _logicScriptCode != null) {
      _updateCartFixed(dt);
      _root['logic_grids'] = logicGridsJson;
      return;
    }
    _runEntityScripts(dt);
    _updatePhysics(dt);
    _applySpriteAnimationUv(dt);
  }

  void _updateCartFixed(double dt) {
    const fixed = 1.0 / 60.0;
    const maxSteps = 5;
    _simAccumulator += dt;
    var steps = 0;
    while (_simAccumulator >= fixed && steps < maxSteps) {
      _simAccumulator -= fixed;
      _runCartLogicStep(fixed);
      steps++;
    }
  }

  void _runCartLogicStep(double dt) {
    final input = logicGrids.input;
    input.setKey('w', _keys.w);
    input.setKey('a', _keys.a);
    input.setKey('s', _keys.s);
    input.setKey('d', _keys.d);
    input.setKey(' ', _keys.space);
    input.setNamed('LEFT', _keys.left);
    input.setNamed('RIGHT', _keys.right);
    input.setNamed('UP', _keys.up);
    input.setNamed('DOWN', _keys.down);
    input.setNamed('ENTER', _keys.enter);
    input.setGamepad(_gamepadMask);
    input.setActions(_resolveActions());
    final globals = input.luaGlobals();
    final err = _luaRuntime?.runFrame(dt, globals);
    if (err != null && err.isNotEmpty) {
      logicGrids.log(err);
    }
    input.endFrame();
  }

  Map<String, bool> _resolveActions() {
    final raw = _root['input_map'];
    final map = <String, bool>{};
    if (raw is! Map) return map;
    for (final e in raw.entries) {
      final keys = e.value;
      final list = keys is List
          ? keys.map((x) => x.toString()).toList()
          : keys is String
              ? [keys]
              : <String>[];
      map[e.key.toString()] = list.any(_keyTokenPressed);
    }
    return map;
  }

  bool _keyTokenPressed(String token) {
    switch (token.trim().toUpperCase()) {
      case 'W':
        return _keys.w;
      case 'A':
        return _keys.a;
      case 'S':
        return _keys.s;
      case 'D':
        return _keys.d;
      case 'SPACE':
      case 'SPACEBAR':
        return _keys.space;
      case 'LEFT':
      case 'ARROWLEFT':
        return _keys.left;
      case 'RIGHT':
      case 'ARROWRIGHT':
        return _keys.right;
      case 'UP':
      case 'ARROWUP':
        return _keys.up;
      case 'DOWN':
      case 'ARROWDOWN':
        return _keys.down;
      case 'RETURN':
      case 'ENTER':
        return _keys.enter;
      default:
        return false;
    }
  }

  Map<String, bool> _keyGlobals() => {
        'key_w': _keys.w,
        'key_a': _keys.a,
        'key_s': _keys.s,
        'key_d': _keys.d,
        'key_space': _keys.space,
        'key_left': _keys.left,
        'key_right': _keys.right,
        'key_up': _keys.up,
        'key_down': _keys.down,
        'key_enter': _keys.enter,
      };

  void _runEntityScripts(double dt) {
    final actions = _resolveActions();
    final keyG = _keyGlobals();
    var entities = _entities.map((e) => Map<String, dynamic>.from(e)).toList();

    for (final e in entities) {
      final script = e['script'];
      if (script is! Map || script['code'] is! String) continue;
      final code = script['code'] as String;
      if (code.trim().isEmpty || code == 'web') continue;

      final phys = e['physics'] as Map<String, dynamic>?;
      if (phys == null || phys['is_static'] == true) continue;

      final vel = phys['velocity'] as Map? ?? const {'x': 0.0, 'y': 0.0};
      final ctx = WebScriptContext(
        actions: actions,
        keys: keyG,
        onGround: e['on_ground'] == true,
        vx: (vel['x'] as num?)?.toDouble() ?? 0,
        vy: (vel['y'] as num?)?.toDouble() ?? 0,
        entityId: (e['id'] as num?)?.toInt() ?? 0,
      );
      runWebEntityScript(code, ctx, dt: dt);

      if (ctx.pendingSceneLoad != null) {
        _pendingLoad = ctx.pendingSceneLoad;
      }
      if (ctx.newVx != null || ctx.newVy != null) {
        final v = Map<String, dynamic>.from(phys['velocity'] as Map? ?? {});
        if (ctx.newVx != null) v['x'] = ctx.newVx;
        if (ctx.newVy != null) v['y'] = ctx.newVy;
        phys['velocity'] = v;
      }
    }
    _entities = entities;
  }

  void _applySpriteAnimationUv(double dt) {
    var entities = _entities.map((e) => Map<String, dynamic>.from(e)).toList();
    for (final e in entities) {
      final sp = Map<String, dynamic>.from(e['sprite'] as Map? ?? {});
      final anim = sp['animation'] as Map?;
      final frames = (anim?['frames'] as List?)?.cast<Map>();
      if (frames == null || frames.isEmpty) continue;
      final fps = (anim?['fps'] as num?)?.toDouble() ?? 8;
      final animatorRaw = e['animator'] as Map?;
      final looping = animatorRaw?['looping'] as bool? ?? true;
      double t;
      if (animatorRaw != null) {
        final animator = Map<String, dynamic>.from(animatorRaw);
        t = (animator['time'] as num?)?.toDouble() ?? 0;
        final speed = (animator['speed'] as num?)?.toDouble() ?? 1;
        t += dt * speed;
        animator['time'] = t;
        e['animator'] = animator;
      } else {
        t = ((e['_playback'] as num?)?.toDouble() ?? 0) + dt;
        e['_playback'] = t;
      }
      final idx = looping
          ? (t * fps).floor() % frames.length
          : (t * fps).floor().clamp(0, frames.length - 1);
      sp['uv_rect'] = Map<String, dynamic>.from(frames[idx]);
      e['sprite'] = sp;
    }
    _entities = entities;
  }

  void _updatePhysics(double dt) {
    final n = _physicsSubstepCount(_entities, dt);
    final h = dt / n;
    var entities = _entities.map((e) => Map<String, dynamic>.from(e)).toList();
    for (var k = 0; k < n; k++) {
      entities = _physicsSubstep(entities, h);
    }
    _updateGrounded(entities);
    _entities = entities;
  }

  int _physicsSubstepCount(List<Map<String, dynamic>> entities, double dt) {
    var maxR = 0.0;
    for (final e in entities) {
      final phys = e['physics'] as Map<String, dynamic>?;
      if (phys == null || phys['is_static'] == true) continue;
      final vel = phys['velocity'] as Map? ?? const {'x': 0.0, 'y': 0.0};
      final vx = (vel['x'] as num).toDouble();
      final vy = (vel['y'] as num).toDouble();
      final speed = math.sqrt(vx * vx + vy * vy) * dt;
      final tf = e['transform'] as Map?;
      final sz = tf?['size'] as Map?;
      if (sz == null) continue;
      final sw = (sz['x'] as num).toDouble();
      final sh = (sz['y'] as num).toDouble();
      final thin = sw < sh ? sw : sh;
      final characteristic = (thin < 4.0 ? 4.0 : thin) * 0.35;
      final r = speed / characteristic;
      if (r > maxR) maxR = r;
    }
    var n = maxR.ceil();
    if (n < 1) n = 1;
    if (n > 16) n = 16;
    return n;
  }

  List<Map<String, dynamic>> _physicsSubstep(List<Map<String, dynamic>> entities, double dt) {
    const gravity = 900.0;
    final list = entities.map((e) => Map<String, dynamic>.from(e)).toList();

    for (final e in list) {
      final phys = e['physics'] as Map<String, dynamic>?;
      if (phys == null || phys['is_static'] == true) continue;
      final useG = phys['use_gravity'] != false;
      final vel = Map<String, dynamic>.from(phys['velocity'] as Map? ?? {'x': 0.0, 'y': 0.0});
      if (useG) {
        vel['x'] = (vel['x'] as num).toDouble();
        vel['y'] = (vel['y'] as num).toDouble() + gravity * dt;
      }
      final tf = Map<String, dynamic>.from(e['transform'] as Map);
      final pos = Map<String, dynamic>.from(tf['pos'] as Map);
      pos['x'] = (pos['x'] as num).toDouble() + (vel['x'] as num).toDouble() * dt;
      pos['y'] = (pos['y'] as num).toDouble() + (vel['y'] as num).toDouble() * dt;
      tf['pos'] = pos;
      e['transform'] = tf;
      phys['velocity'] = vel;
    }

    _resolveCollisions(list);
    return list;
  }

  void _resolveCollisions(List<Map<String, dynamic>> entities) {
    final n = entities.length;
    for (var iter = 0; iter < 3; iter++) {
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          _pairResolve(entities, i, j);
        }
      }
    }
  }

  void _pairResolve(List<Map<String, dynamic>> entities, int i, int j) {
    final e1 = entities[i];
    final e2 = entities[j];
    final p1 = e1['physics'] as Map?;
    final p2 = e2['physics'] as Map?;
    if (p1?['is_trigger'] == true || p2?['is_trigger'] == true) return;
    final r1 = _rect(e1);
    final r2 = _rect(e2);
    if (r1 == null || r2 == null) return;
    if (!_overlap(r1, r2)) return;

    final dx = (r1.cx - r2.cx).abs();
    final dy = (r1.cy - r2.cy).abs();
    final overlapX = (r1.w + r2.w) / 2 - dx;
    final overlapY = (r1.h + r2.h) / 2 - dy;
    if (overlapX <= 0 || overlapY <= 0) return;

    final s1 = _isStatic(e1);
    final s2 = _isStatic(e2);
    if (s1 && s2) return;

    if (overlapX < overlapY) {
      final dir = r1.cx < r2.cx ? -1.0 : 1.0;
      final push = overlapX;
      if (!s1) _pushX(e1, dir * push * (s2 ? 1.0 : 0.5));
      if (!s2) _pushX(e2, -dir * push * (s1 ? 1.0 : 0.5));
      if (!s1) _bounceX(e1);
      if (!s2) _bounceX(e2);
    } else {
      final dir = r1.cy < r2.cy ? -1.0 : 1.0;
      final push = overlapY;
      if (!s1) _pushY(e1, dir * push * (s2 ? 1.0 : 0.5));
      if (!s2) _pushY(e2, -dir * push * (s1 ? 1.0 : 0.5));
      if (!s1) _bounceY(e1, dir);
      if (!s2) _bounceY(e2, -dir);
    }
  }

  _R? _rect(Map<String, dynamic> e) {
    final tf = e['transform'] as Map?;
    if (tf == null) return null;
    final pos = tf['pos'] as Map?;
    final size = tf['size'] as Map?;
    if (pos == null || size == null) return null;
    final x = (pos['x'] as num).toDouble();
    final y = (pos['y'] as num).toDouble();
    final w = (size['x'] as num).toDouble();
    final h = (size['y'] as num).toDouble();
    return _R(x - w / 2, y - h / 2, w, h);
  }

  bool _overlap(_R a, _R b) =>
      a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

  bool _isStatic(Map<String, dynamic> e) {
    final phys = e['physics'] as Map?;
    if (phys == null) return true;
    return phys['is_static'] == true;
  }

  bool _isDynamic(Map<String, dynamic> e) {
    final phys = e['physics'] as Map?;
    if (phys == null) return false;
    return phys['is_static'] != true;
  }

  void _pushX(Map<String, dynamic> e, double dx) {
    final tf = Map<String, dynamic>.from(e['transform'] as Map);
    final pos = Map<String, dynamic>.from(tf['pos'] as Map);
    pos['x'] = (pos['x'] as num).toDouble() + dx;
    tf['pos'] = pos;
    e['transform'] = tf;
  }

  void _pushY(Map<String, dynamic> e, double dy) {
    final tf = Map<String, dynamic>.from(e['transform'] as Map);
    final pos = Map<String, dynamic>.from(tf['pos'] as Map);
    pos['y'] = (pos['y'] as num).toDouble() + dy;
    tf['pos'] = pos;
    e['transform'] = tf;
  }

  void _bounceX(Map<String, dynamic> e) {
    final phys = e['physics'] as Map?;
    if (phys == null) return;
    final b = (phys['bounciness'] as num?)?.toDouble() ?? 0.5;
    final vel = Map<String, dynamic>.from(phys['velocity'] as Map? ?? {});
    vel['x'] = -(vel['x'] as num).toDouble() * b;
    phys['velocity'] = vel;
  }

  void _bounceY(Map<String, dynamic> e, double normalDir) {
    final phys = e['physics'] as Map?;
    if (phys == null) return;
    final b = (phys['bounciness'] as num?)?.toDouble() ?? 0.5;
    final vel = Map<String, dynamic>.from(phys['velocity'] as Map? ?? {});
    final vy = (vel['y'] as num).toDouble();
    if ((normalDir > 0 && vy < 0) || (normalDir < 0 && vy > 0)) {
      vel['y'] = 0.0;
    } else {
      vel['y'] = -vy * b;
    }
    vel['x'] = (vel['x'] as num).toDouble() * 0.95;
    phys['velocity'] = vel;
  }

  void _updateGrounded(List<Map<String, dynamic>> entities) {
    final n = entities.length;
    for (var i = 0; i < n; i++) {
      if (!_isDynamic(entities[i])) {
        entities[i]['on_ground'] = false;
        continue;
      }
      final e = entities[i];
      final r = _rect(e);
      if (r == null) {
        e['on_ground'] = false;
        continue;
      }
      final bottom = r.y + r.h;
      final left = r.x;
      final right = r.x + r.w;
      final vy = ((e['physics'] as Map)['velocity'] as Map)['y'] as num? ?? 0;
      var grounded = false;
      for (var j = 0; j < n; j++) {
        if (i == j || !_isStatic(entities[j])) continue;
        final o = entities[j];
        final ro = _rect(o);
        if (ro == null) continue;
        final top = ro.y;
        final oleft = ro.x;
        final oright = ro.x + ro.w;
        if (bottom >= top - 4 &&
            bottom <= top + 12 &&
            right > oleft + 1 &&
            left < oright - 1 &&
            vy >= -120) {
          grounded = true;
          break;
        }
      }
      e['on_ground'] = grounded;
    }
  }
}

class _R {
  _R(this.x, this.y, this.w, this.h);
  final double x, y, w, h;
  double get cx => x + w / 2;
  double get cy => y + h / 2;
}

class _KeyState {
  bool w = false, a = false, s = false, d = false, space = false;
  bool left = false, right = false, up = false, down = false, enter = false;

  void setNamed(String name, bool pressed) {
    switch (name.trim().toUpperCase()) {
      case 'LEFT':
      case 'ARROWLEFT':
        left = pressed;
        break;
      case 'RIGHT':
      case 'ARROWRIGHT':
        right = pressed;
        break;
      case 'UP':
      case 'ARROWUP':
        up = pressed;
        break;
      case 'DOWN':
      case 'ARROWDOWN':
        down = pressed;
        break;
      case 'RETURN':
      case 'ENTER':
        enter = pressed;
        break;
      case 'W':
        w = pressed;
        break;
      case 'A':
        a = pressed;
        break;
      case 'S':
        s = pressed;
        break;
      case 'D':
        d = pressed;
        break;
      case 'SPACE':
      case 'SPACEBAR':
        space = pressed;
        break;
      default:
        setKey(name, pressed);
    }
  }

  void setKey(String key, bool pressed) {
    final c = key.isNotEmpty ? key[0] : '';
    switch (c) {
      case 'w':
      case 'W':
        w = pressed;
        break;
      case 'a':
      case 'A':
        a = pressed;
        break;
      case 's':
      case 'S':
        s = pressed;
        break;
      case 'd':
      case 'D':
        d = pressed;
        break;
      case ' ':
        space = pressed;
        break;
    }
  }
}
