import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class NexusPlaySnapshot {
  static const String nexusDir = '.nexus';
  static const String fileName = 'play_snapshot.json';

  static File snapshotFile(String projectRoot) =>
      File(p.join(projectRoot, nexusDir, fileName));

  static Future<void> ensureNexusDir(String projectRoot) async {
    await Directory(p.join(projectRoot, nexusDir)).create(recursive: true);
  }

  static Future<bool> exists(String projectRoot) async =>
      await snapshotFile(projectRoot).exists();

  static Future<String?> readOrNull(String projectRoot) async {
    final f = snapshotFile(projectRoot);
    if (!await f.exists()) return null;
    try {
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String projectRoot, String engineJson) async {
    await ensureNexusDir(projectRoot);
    final f = snapshotFile(projectRoot);
    final map = {
      'snapshotVersion': 1,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'engineScene': jsonDecode(engineJson),
    };
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
  }

  static Future<String?> loadEngineJsonOrNull(String projectRoot) async {
    final raw = await readOrNull(projectRoot);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final inner = m['engineScene'];
      if (inner is Map<String, dynamic>) {
        return jsonEncode(inner);
      }
      return raw;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String projectRoot) async {
    final f = snapshotFile(projectRoot);
    if (await f.exists()) await f.delete();
  }
}
