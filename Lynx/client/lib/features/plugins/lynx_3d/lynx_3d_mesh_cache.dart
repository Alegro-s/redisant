import 'package:path/path.dart' as p;

import 'lynx_glb_mesh.dart';

/// Кэш GLB по относительному пути в проекте.
class Lynx3dMeshCache {
  Lynx3dMeshCache({this.projectRoot});

  String? projectRoot;
  final Map<String, LynxGlbMesh> _cache = {};

  Future<Map<String, LynxGlbMesh>> loadForMeshes(Iterable<String?> meshPaths) async {
    final out = <String, LynxGlbMesh>{};
    for (final rel in meshPaths) {
      if (rel == null || rel.isEmpty) continue;
      if (_cache.containsKey(rel)) {
        out[rel] = _cache[rel]!;
        continue;
      }
      final mesh = await _loadOne(rel);
      _cache[rel] = mesh;
      out[rel] = mesh;
    }
    return out;
  }

  Future<LynxGlbMesh> _loadOne(String rel) async {
    final root = projectRoot;
    if (root != null && root.isNotEmpty) {
      final abs = p.join(root, rel.replaceAll('/', p.separator));
      final loaded = await LynxGlbMesh.loadFile(abs);
      if (loaded != null) return loaded;
    }
    return LynxGlbMesh.unitCube();
  }

  void clear() => _cache.clear();
}
