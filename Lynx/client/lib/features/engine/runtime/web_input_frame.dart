class WebInputFrame {
  bool w = false, a = false, s = false, d = false;
  bool space = false, left = false, right = false, up = false, down = false, enter = false;
  bool gpA = false, gpB = false, gpLeft = false, gpRight = false, gpUp = false, gpDown = false;

  bool _pw = false, _pa = false, _ps = false, _pd = false;
  bool _pspace = false, _pleft = false, _pright = false, _pup = false, _pdown = false, _penter = false;
  bool _pGpA = false, _pGpB = false, _pGpLeft = false, _pGpRight = false, _pGpUp = false, _pGpDown = false;

  final Map<String, bool> actions = {};
  final Map<String, bool> _prevActions = {};

  void setKey(String key, bool pressed) {
    switch (key.toLowerCase()) {
      case 'w':
        w = pressed;
      case 'a':
        a = pressed;
      case 's':
        s = pressed;
      case 'd':
        d = pressed;
      case ' ':
        space = pressed;
      default:
        break;
    }
  }

  void setNamed(String name, bool pressed) {
    switch (name.trim().toUpperCase()) {
      case 'LEFT':
      case 'ARROWLEFT':
        left = pressed;
      case 'RIGHT':
      case 'ARROWRIGHT':
        right = pressed;
      case 'UP':
      case 'ARROWUP':
        up = pressed;
      case 'DOWN':
      case 'ARROWDOWN':
        down = pressed;
      case 'RETURN':
      case 'ENTER':
        enter = pressed;
      case 'W':
        w = pressed;
      case 'A':
        a = pressed;
      case 'S':
        s = pressed;
      case 'D':
        d = pressed;
      case 'SPACE':
      case 'SPACEBAR':
        space = pressed;
      default:
        break;
    }
  }

  void setGamepad(int mask) {
    gpA = mask & 1 != 0;
    gpB = mask & 2 != 0;
    gpLeft = mask & 4 != 0;
    gpRight = mask & 8 != 0;
    gpUp = mask & 16 != 0;
    gpDown = mask & 32 != 0;
  }

  void setActions(Map<String, bool> next) {
    actions
      ..clear()
      ..addAll(next);
  }

  bool keyHeld(String name) {
    switch (name.trim().toLowerCase()) {
      case 'left':
        return left || gpLeft;
      case 'right':
        return right || gpRight;
      case 'up':
        return up || gpUp;
      case 'down':
        return down || gpDown;
      case 'space':
        return space;
      case 'gp_a':
        return gpA;
      case 'gp_b':
        return gpB;
      default:
        return false;
    }
  }

  bool btnPressed(String name) {
    switch (name.trim().toLowerCase()) {
      case 'a':
      case 'gp_a':
      case 'jump':
      case 'confirm':
        return gpA && !_pGpA;
      case 'b':
      case 'gp_b':
      case 'cancel':
        return gpB && !_pGpB;
      case 'left':
      case 'dleft':
      case 'gp_dleft':
        return gpLeft && !_pGpLeft;
      case 'right':
      case 'dright':
      case 'gp_dright':
        return gpRight && !_pGpRight;
      case 'up':
      case 'dup':
      case 'gp_dup':
        return gpUp && !_pGpUp;
      case 'down':
      case 'ddown':
      case 'gp_ddown':
        return gpDown && !_pGpDown;
      case 'space':
        return space && !_pspace;
      case 'enter':
        return enter && !_penter;
      case 'w':
        return w && !_pw;
      case 'a':
        return a && !_pa;
      case 's':
        return s && !_ps;
      case 'd':
        return d && !_pd;
      default:
        return false;
    }
  }

  bool actionPressed(String name) {
    final cur = actions[name] ?? false;
    final prev = _prevActions[name] ?? false;
    return cur && !prev;
  }

  void endFrame() {
    _pw = w;
    _pa = a;
    _ps = s;
    _pd = d;
    _pspace = space;
    _pleft = left;
    _pright = right;
    _pup = up;
    _pdown = down;
    _penter = enter;
    _pGpA = gpA;
    _pGpB = gpB;
    _pGpLeft = gpLeft;
    _pGpRight = gpRight;
    _pGpUp = gpUp;
    _pGpDown = gpDown;
    _prevActions
      ..clear()
      ..addAll(actions);
  }

  Map<String, dynamic> luaGlobals() => {
        'key_w': w,
        'key_a': a,
        'key_s': s,
        'key_d': d,
        'key_space': space,
        'key_left': left,
        'key_right': right,
        'key_up': up,
        'key_down': down,
        'key_enter': enter,
        'gp_a': gpA,
        'gp_b': gpB,
        'gp_dleft': gpLeft,
        'gp_dright': gpRight,
        'gp_dup': gpUp,
        'gp_ddown': gpDown,
      };
}
