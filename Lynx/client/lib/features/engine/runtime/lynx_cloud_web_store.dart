import 'dart:convert';
import 'dart:typed_data';

import '../models/engine_models.dart';

const String kLynxCloudWebPrefix = 'lynx-cloud-web:';

bool isLynxCloudWebRoot(String? path) =>
    path != null && path.startsWith(kLynxCloudWebPrefix);

String lynxCloudWebRoot(String projectId) => '$kLynxCloudWebPrefix$projectId';

String cloudProjectIdFromWebRoot(String webRoot) =>
    webRoot.substring(kLynxCloudWebPrefix.length);

/// In-memory cloud project cache for Flutter Web (no dart:io).
class LynxCloudWebStore {
  LynxCloudWebStore({
    required this.projectId,
    required this.settings,
  });

  final String projectId;
  GameProject settings;
  final Map<String, Uint8List> files = {};
  final List<Scene> scenes = [];

  Uint8List? readBytes(String rel) {
    final key = rel.replaceAll('\\', '/');
    return files[key];
  }

  void writeBytes(String rel, Uint8List bytes) {
    files[rel.replaceAll('\\', '/')] = bytes;
  }

  void writeText(String rel, String text) {
    writeBytes(rel, Uint8List.fromList(utf8.encode(text)));
  }

  String? readText(String rel) {
    final bytes = readBytes(rel);
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  Iterable<String> assetFilePaths() => files.keys.where(
        (k) => k.startsWith('assets/') && !k.endsWith('.meta.json'),
      );
}

final Map<String, LynxCloudWebStore> lynxCloudWebSessionCache = {};
