import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Импорт glTF/GLB в `assets/models/` (волна 6c).
class LynxGltfImport {
  /// Копирует файл и пишет sidecar `{name}.lynx3d.json` с halfExtents.
  static Future<String?> pickAndImportGlb(String projectRoot) async {
    if (kIsWeb) return null;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['glb', 'gltf'],
      allowMultiple: false,
    );
    if (pick == null || pick.files.isEmpty) return null;
    final path = pick.files.single.path;
    if (path == null || path.isEmpty) return null;
    return importFile(projectRoot, path);
  }

  static Future<String> importFile(String projectRoot, String sourcePath) async {
    final modelsDir = Directory(p.join(projectRoot, 'assets', 'models'));
    if (!modelsDir.existsSync()) {
      modelsDir.createSync(recursive: true);
    }
    final base = p.basename(sourcePath);
    final dest = p.join(modelsDir.path, base);
    await File(sourcePath).copy(dest);

    final half = _guessHalfExtents(dest);
    final metaPath = p.join(modelsDir.path, '${p.basenameWithoutExtension(base)}.lynx3d.json');
    await File(metaPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'source': 'assets/models/$base',
        'halfExtents': half,
        'importedAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    return 'assets/models/$base';
  }

  static List<double> _guessHalfExtents(String glbPath) {
    try {
      final bytes = File(glbPath).readAsBytesSync();
      if (bytes.length < 20) return [0.5, 0.5, 0.5];
      final magic = String.fromCharCodes(bytes.sublist(0, 4));
      if (magic != 'glTF') return [0.5, 0.5, 0.5];
      final jsonLen = bytes[12] | (bytes[13] << 8) | (bytes[14] << 16) | (bytes[15] << 24);
      if (jsonLen <= 0 || 20 + jsonLen > bytes.length) return [0.5, 0.5, 0.5];
      final chunk = utf8.decode(bytes.sublist(20, 20 + jsonLen), allowMalformed: true);
      final map = jsonDecode(chunk) as Map<String, dynamic>;
      final nodes = map['nodes'] as List?;
      if (nodes == null || nodes.isEmpty) return [0.5, 0.5, 0.5];
      final meshes = map['meshes'] as List?;
      if (meshes == null) return [0.5, 0.5, 0.5];
      double maxExt = 0.5;
      for (final mesh in meshes) {
        final prims = mesh['primitives'] as List?;
        if (prims == null) continue;
        for (final prim in prims) {
          if (prim is! Map) continue;
          final attrs = prim['attributes'] as Map?;
          final posIdx = attrs?['POSITION'];
          if (posIdx is! int) continue;
          final accessors = map['accessors'] as List?;
          if (accessors == null || posIdx >= accessors.length) continue;
          final acc = accessors[posIdx];
          if (acc is! Map) continue;
          final maxArr = acc['max'] as List?;
          final minArr = acc['min'] as List?;
          if (maxArr != null && minArr != null && maxArr.length >= 3 && minArr.length >= 3) {
            for (var i = 0; i < 3; i++) {
              final half = ((maxArr[i] as num) - (minArr[i] as num)).abs() * 0.5;
              if (half > maxExt) maxExt = half.toDouble();
            }
          }
        }
      }
      return [maxExt, maxExt, maxExt];
    } catch (_) {
      return [0.5, 0.5, 0.5];
    }
  }
}
