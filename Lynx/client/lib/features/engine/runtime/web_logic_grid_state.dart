import 'web_input_frame.dart';

class WebLogicGridState {
  final Map<String, _Grid> grids = {};
  final WebInputFrame input = WebInputFrame();
  final List<String> debugLog = [];

  void ensure(String name, int w, int h) {
    grids.putIfAbsent(name, () => _Grid(w, h));
    final g = grids[name]!;
    if (g.w != w || g.h != h) {
      grids[name] = _Grid(w, h);
    }
  }

  int get(String name, int x, int y) => grids[name]?.get(x, y) ?? 0;

  void set(String name, int x, int y, int v) => grids[name]?.set(x, y, v);

  void fill(String name, int v) => grids[name]?.fill(v);

  int width(String name) => grids[name]?.w ?? 0;

  void log(String msg) {
    debugLog.add(msg);
    if (debugLog.length > 200) debugLog.removeAt(0);
  }

  Map<String, Map<String, dynamic>> toSceneJson() {
    return {
      for (final e in grids.entries) e.key: e.value.toJson(),
    };
  }

  void loadFromScene(Map<String, dynamic>? raw) {
    if (raw == null) return;
    for (final e in raw.entries) {
      if (e.value is! Map) continue;
      final m = Map<String, dynamic>.from(e.value as Map);
      final w = (m['w'] as num?)?.toInt() ?? 0;
      final h = (m['h'] as num?)?.toInt() ?? 0;
      if (w <= 0 || h <= 0) continue;
      final g = _Grid(w, h);
      g.loadCells(m['cells']);
      grids[e.key] = g;
    }
  }
}

class _Grid {
  _Grid(this.w, this.h) : cells = List.filled(w * h, 0);

  final int w;
  final int h;
  final List<int> cells;

  int get(int x, int y) {
    if (x < 0 || y < 0 || x >= w || y >= h) return 0;
    return cells[y * w + x];
  }

  void set(int x, int y, int v) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    cells[y * w + x] = v;
  }

  void fill(int v) {
    for (var i = 0; i < cells.length; i++) {
      cells[i] = v;
    }
  }

  void loadCells(dynamic raw) {
    if (raw is! List) return;
    for (var i = 0; i < cells.length && i < raw.length; i++) {
      cells[i] = (raw[i] as num?)?.toInt() ?? 0;
    }
  }

  Map<String, dynamic> toJson() => {
        'w': w,
        'h': h,
        'cells': cells,
      };
}
