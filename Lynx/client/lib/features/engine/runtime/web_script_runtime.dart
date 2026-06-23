/// Упрощённый Lua-подмножество для WebSceneEngine (волна 4).

class WebScriptContext {
  final Map<String, bool> actions;
  final Map<String, bool> keys;
  final bool onGround;
  final double vx;
  final double vy;
  final int entityId;
  final Map<String, double> vars = {};
  double? newVx;
  double? newVy;
  String? pendingSceneLoad;
  final List<String> debugLog;

  WebScriptContext({
    required this.actions,
    required this.keys,
    required this.onGround,
    required this.vx,
    required this.vy,
    required this.entityId,
    List<String>? debugLog,
  }) : debugLog = debugLog ?? [];

  bool boolVar(String name) {
    if (name == 'on_ground') return onGround;
    if (name.startsWith('action_')) {
      return actions[name.substring(7)] ?? false;
    }
    if (name.startsWith('key_')) {
      return keys[name] ?? false;
    }
    return false;
  }

  double numVar(String name) {
    if (name == 'vx') return vx;
    if (name == 'vy') return vy;
    if (name == 'dt') return vars['dt'] ?? 0;
    return vars[name] ?? 0;
  }
}

void runWebEntityScript(String code, WebScriptContext ctx, {required double dt}) {
  ctx.vars['dt'] = dt;
  final lines = _preprocess(code);
  for (final line in lines) {
    _runLine(line, ctx);
  }
}

List<String> _preprocess(String code) {
  final out = <String>[];
  for (final raw in code.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('--')) continue;
    if (line.startsWith('local ')) {
      line = line.substring(6).trim();
    }
    if (line.endsWith(';')) line = line.substring(0, line.length - 1);
    out.add(line);
  }
  return out;
}

void _runLine(String line, WebScriptContext ctx) {
  if (line.startsWith('if ') && line.endsWith(' end')) {
    final inner = line.substring(3, line.length - 4).trim();
    final thenIdx = _indexOfThen(inner);
    if (thenIdx < 0) return;
    final cond = inner.substring(0, thenIdx).trim();
    final body = inner.substring(thenIdx + 4).trim();
    if (_evalCondition(cond, ctx)) {
      _runLine(body, ctx);
    }
    return;
  }

  final assign = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$');
  final am = assign.firstMatch(line);
  if (am != null) {
    final name = am.group(1)!;
    final expr = am.group(2)!.trim();
    ctx.vars[name] = _evalNumber(expr, ctx);
    return;
  }

  if (line.startsWith('set_velocity(') && line.endsWith(')')) {
    final inner = line.substring(13, line.length - 1);
    final parts = inner.split(',').map((s) => s.trim()).toList();
    if (parts.length >= 2) {
      ctx.newVx = _evalNumber(parts[0], ctx);
      ctx.newVy = _evalNumber(parts[1], ctx);
    }
    return;
  }

  final load = RegExp(r'''load_scene\s*\(\s*["']([^"']+)["']\s*\)''');
  final lm = load.firstMatch(line);
  if (lm != null) {
    ctx.pendingSceneLoad = lm.group(1);
    return;
  }

  if (line.startsWith('emit_signal(')) {
    // Сигналы на вебе пока no-op (волна 4).
    return;
  }
}

int _indexOfThen(String s) {
  final lower = s.toLowerCase();
  var depth = 0;
  for (var i = 0; i < s.length - 3; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') depth--;
    if (depth == 0 && lower.startsWith('then', i)) {
      return i;
    }
  }
  return -1;
}

bool _evalCondition(String cond, WebScriptContext ctx) {
  cond = cond.trim();
  if (cond.contains(' or ')) {
    return cond.split(RegExp(r'\s+or\s+')).any((p) => _evalCondition(p.trim(), ctx));
  }
  if (cond.contains(' and ')) {
    return cond.split(RegExp(r'\s+and\s+')).every((p) => _evalCondition(p.trim(), ctx));
  }
  if (cond.startsWith('not ')) {
    return !_evalCondition(cond.substring(4).trim(), ctx);
  }
  if (cond.startsWith('(') && cond.endsWith(')')) {
    return _evalCondition(cond.substring(1, cond.length - 1).trim(), ctx);
  }
  if (cond == 'true') return true;
  if (cond == 'false') return false;
  return ctx.boolVar(cond);
}

double _evalNumber(String expr, WebScriptContext ctx) {
  expr = expr.trim();
  if (expr.startsWith('(') && expr.endsWith(')')) {
    return _evalNumber(expr.substring(1, expr.length - 1), ctx);
  }
  final numLit = double.tryParse(expr);
  if (numLit != null) return numLit;
  if (expr.startsWith('-')) {
    return -_evalNumber(expr.substring(1), ctx);
  }
  for (final op in ['+', '-']) {
    final idx = expr.lastIndexOf(op);
    if (idx > 0) {
      final left = expr.substring(0, idx).trim();
      final right = expr.substring(idx + 1).trim();
      final a = _evalNumber(left, ctx);
      final b = _evalNumber(right, ctx);
      return op == '+' ? a + b : a - b;
    }
  }
  return ctx.numVar(expr);
}
