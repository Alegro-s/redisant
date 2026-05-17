import 'dart:convert';

class CollabHlc {
  final int wallMs;
  final int logical;
  final String site;

  const CollabHlc({required this.wallMs, required this.logical, required this.site});

  Map<String, dynamic> toJson() => {
        'wall_ms': wallMs,
        'logical': logical,
        'site': site,
      };
}

String _escapeJsonPointerSegment(String k) {
  return k.replaceAll('~', '~0').replaceAll('/', '~1');
}

bool _jsonEq(dynamic a, dynamic b) {
  try {
    return jsonEncode(a) == jsonEncode(b);
  } catch (_) {
    return false;
  }
}

List<Map<String, dynamic>> buildSceneCrdtOps({
  required Map<String, dynamic>? previous,
  required Map<String, dynamic> current,
  required CollabHlc Function() nextHlc,
}) {
  final ops = <Map<String, dynamic>>[];

  void walk(String ptr, dynamic oldV, dynamic newV) {
    if (_jsonEq(oldV, newV)) {
      return;
    }
    if (oldV == null && newV is Map) {
      walk(ptr, <String, dynamic>{}, newV);
      return;
    }
    if (newV == null) {
      ops.add({
        'path': ptr.isEmpty ? '/' : ptr,
        'value': null,
        'hlc': nextHlc().toJson(),
      });
      return;
    }
    if (oldV is Map && newV is Map) {
      final oldM = oldV.cast<String, dynamic>();
      final newM = newV.cast<String, dynamic>();
      final keys = {...oldM.keys, ...newM.keys};
      for (final k in keys) {
        final seg = _escapeJsonPointerSegment(k);
        final nextPtr = ptr.isEmpty ? '/$seg' : '$ptr/$seg';
        walk(nextPtr, oldM[k], newM[k]);
      }
      return;
    }
    ops.add({
      'path': ptr.isEmpty ? '/' : ptr,
      'value': newV,
      'hlc': nextHlc().toJson(),
    });
  }

  if (previous == null) {
    ops.add({
      'path': '',
      'value': current,
      'hlc': nextHlc().toJson(),
    });
    return ops;
  }

  walk('', previous, current);
  return ops;
}
