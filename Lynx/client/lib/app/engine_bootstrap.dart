import 'package:flutter/foundation.dart' show kIsWeb;

import '../features/launcher/android_engine_intent_stub.dart'
    if (dart.library.io) '../features/launcher/android_engine_intent.dart';
import 'engine_platform.dart' as plat;
import 'bootstrap_raw_stub.dart'
    if (dart.library.io) 'bootstrap_raw_io.dart' as raw;

/// Parse E25b `?project=cloud:<id>` from web hub deep link.
EngineBootstrap? _bootstrapFromWebUri() {
  if (!kIsWeb) return null;
  final uri = Uri.base;
  if (uri.path.contains('engine') || uri.queryParameters.isNotEmpty) {
    final project = uri.queryParameters['project']?.trim();
    final projectId = uri.queryParameters['projectId']?.trim();
    final name = uri.queryParameters['projectName']?.trim();
    final readOnly = uri.queryParameters['readOnly'] == '1' ||
        uri.queryParameters['cloudReadOnly'] == 'true';
    String? cloudId;
    if (project != null && project.startsWith('cloud:')) {
      cloudId = project.substring(6);
    } else if (projectId != null && projectId.isNotEmpty) {
      cloudId = projectId;
    }
    if (cloudId != null && cloudId.isNotEmpty) {
      return EngineBootstrap._(
        projectId: cloudId,
        projectName: name?.isNotEmpty == true ? name : 'Облачный проект',
        cloudReadOnly: readOnly,
      );
    }
  }
  return null;
}

/// Bootstrap args for Lynx Engine process (wave 16).
class EngineBootstrap {
  EngineBootstrap._({
    this.projectId,
    this.projectPath,
    this.projectName,
    this.apiBaseOverride,
    this.cloudReadOnly = false,
    this.engineVersion,
    this.cartPath,
    this.playOnly = false,
    this.launcherSession,
    this.allowStandalone = false,
  });

  static EngineBootstrap? _instance;

  static Future<void> ensureInitialized() async {
    if (_instance != null) return;
    if (kIsWeb) {
      _instance = _bootstrapFromWebUri() ?? EngineBootstrap._(cloudReadOnly: false);
      return;
    }
    if (plat.engineHostIsAndroid) {
      final m = await AndroidEngineIntent.read();
      _instance = _fromMap(m);
      return;
    }
    _instance = _fromMap(raw.readEngineBootstrapRaw());
  }

  static EngineBootstrap get instance {
    if (_instance != null) return _instance!;
    if (kIsWeb) {
      _instance = _bootstrapFromWebUri() ?? EngineBootstrap._(cloudReadOnly: false);
      return _instance!;
    }
    _instance = _fromMap(raw.readEngineBootstrapRaw());
    return _instance!;
  }

  static EngineBootstrap _fromMap(Map<String, dynamic> m) => EngineBootstrap._(
        projectId: m['projectId'] as String?,
        projectPath: m['projectPath'] as String?,
        projectName: m['projectName'] as String?,
        apiBaseOverride: (m['apiBase'] as String?) ?? (m['apiBaseOverride'] as String?),
        cloudReadOnly: m['cloudReadOnly'] as bool? ?? false,
        engineVersion: (m['engineVer'] as String?) ?? (m['engineVersion'] as String?),
        cartPath: m['cartPath'] as String?,
        playOnly: m['playOnly'] as bool? ?? false,
        launcherSession: m['launcherSession'] as String?,
        allowStandalone: m['allowStandalone'] as bool? ?? false,
      );

  final String? projectId;
  final String? projectPath;
  final String? projectName;
  final String? apiBaseOverride;
  final bool cloudReadOnly;
  final String? engineVersion;
  final String? cartPath;
  final bool playOnly;
  final String? launcherSession;
  final bool allowStandalone;

  bool get hasProjectContext =>
      (projectId != null && projectId!.isNotEmpty) ||
      (projectPath != null && projectPath!.isNotEmpty);

  bool get hasCartContext => cartPath != null && cartPath!.isNotEmpty;
}
