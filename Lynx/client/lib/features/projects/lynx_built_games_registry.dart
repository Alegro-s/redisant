import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/runtime/lynx_export_io.dart';

/// L22a — реестр последних сборок проекта для Launcher.
class LynxBuiltGameRecord {
  final String projectPath;
  final String projectName;
  final LynxExportPreset preset;
  final String outputDirectory;
  final List<String> artifactPaths;
  final DateTime builtAt;

  const LynxBuiltGameRecord({
    required this.projectPath,
    required this.projectName,
    required this.preset,
    required this.outputDirectory,
    required this.artifactPaths,
    required this.builtAt,
  });

  String? get primaryArtifact {
    if (artifactPaths.isNotEmpty) return artifactPaths.first;
    return outputDirectory;
  }

  Map<String, dynamic> toJson() => {
        'projectPath': projectPath,
        'projectName': projectName,
        'preset': preset.name,
        'outputDirectory': outputDirectory,
        'artifactPaths': artifactPaths,
        'builtAt': builtAt.toIso8601String(),
      };

  factory LynxBuiltGameRecord.fromJson(Map<String, dynamic> j) {
    LynxExportPreset preset = LynxExportPreset.dataBundle;
    final pName = j['preset'] as String?;
    if (pName != null) {
      for (final v in LynxExportPreset.values) {
        if (v.name == pName) {
          preset = v;
          break;
        }
      }
    }
    return LynxBuiltGameRecord(
      projectPath: j['projectPath'] as String? ?? '',
      projectName: j['projectName'] as String? ?? '',
      preset: preset,
      outputDirectory: j['outputDirectory'] as String? ?? '',
      artifactPaths: (j['artifactPaths'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      builtAt: DateTime.tryParse(j['builtAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LynxBuiltGamesRegistry {
  static const _key = 'lynx_built_games_v1';

  static Future<void> recordBuild(LynxExportResult result, {required String projectPath, required String projectName}) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final list = await loadAll();
    list.removeWhere((r) => r.projectPath == projectPath && r.preset == result.preset);
    list.insert(
      0,
      LynxBuiltGameRecord(
        projectPath: projectPath,
        projectName: projectName,
        preset: result.preset,
        outputDirectory: result.outputDirectory,
        artifactPaths: result.artifactPaths,
        builtAt: DateTime.now(),
      ),
    );
    while (list.length > 32) {
      list.removeLast();
    }
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<List<LynxBuiltGameRecord>> loadAll() async {
    if (kIsWeb) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => LynxBuiltGameRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<LynxBuiltGameRecord?> latestForProject(String projectPath) async {
    final all = await loadAll();
    for (final r in all) {
      if (r.projectPath == projectPath) return r;
    }
    return null;
  }

  static Future<void> openPrimaryArtifact(LynxBuiltGameRecord record) async {
    if (kIsWeb) return;
    final target = record.primaryArtifact;
    if (target == null || target.isEmpty) return;
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', target], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [record.outputDirectory]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [record.outputDirectory]);
    }
  }
}
