import 'lynx_graph_model.dart';

/// Compiles LynxGraph JSON to LynxScript source (`#lynxscript` …).
class LynxGraphCompileError implements Exception {
  LynxGraphCompileError(this.message);
  final String message;
  @override
  String toString() => message;
}

String compileLynxGraphToScript(LynxGraphDocument doc) {
  final buf = StringBuffer('#lynxscript\n');
  _emitStatements(buf, doc.statements, 0);
  buf.writeln('function on_signal()');
  buf.writeln('end');
  return buf.toString();
}

void _emitStatements(StringBuffer buf, List<LynxGraphStatement> stmts, int depth) {
  for (final s in stmts) {
    _emitStatement(buf, s, depth);
  }
}

void _emitStatement(StringBuffer buf, LynxGraphStatement s, int depth) {
  switch (s.type) {
    case 'set_velocity':
      final vx = s.vx ?? '0';
      final vy = s.vy ?? '0';
      buf.writeln('set_velocity(${_expr(vx)}, ${_expr(vy)})');
      return;
    case 'if':
      final cond = s.cond ?? '';
      final head = _ifHead(cond, s.actionName);
      if (head == null) {
        throw LynxGraphCompileError('unsupported condition: $cond');
      }
      buf.writeln('if $head then');
      _emitStatements(buf, s.children, depth + 1);
      buf.writeln('end');
      return;
    case 'noop':
      return;
    default:
      throw LynxGraphCompileError('unsupported node type: ${s.type}');
  }
}

String _expr(String token) {
  final t = token.trim();
  if (t == 'vx' || t == 'vy' || t == 'dt') return t;
  if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t)) return t;
  throw LynxGraphCompileError('bad expression token: $t');
}

String? _ifHead(String cond, String? actionName) {
  switch (cond) {
    case 'key_a':
    case 'key_d':
    case 'key_space':
    case 'on_ground':
      return cond;
    case 'action_pressed':
      final name = actionName ?? 'jump';
      return 'action_pressed("$name")';
    default:
      return null;
  }
}

LynxGraphDocument? tryParseLynxGraphJson(Map<String, dynamic> json) {
  if (json['format']?.toString() != 'lynxgraph') return null;
  return LynxGraphDocument.fromJson(json);
}
