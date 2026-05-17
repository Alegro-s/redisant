import 'package:flutter/foundation.dart' show kIsWeb;

import 'bootstrap_raw_stub.dart'
    if (dart.library.io) 'bootstrap_raw_io.dart' as raw;

class EditorBootstrap {
  EditorBootstrap._({
    this.projectId,
    this.projectName,
    this.apiBaseOverride,
    this.cloudReadOnly = false,
  });

  static EditorBootstrap? _instance;

  static EditorBootstrap get instance {
    if (_instance != null) return _instance!;
    if (kIsWeb) {
      _instance = EditorBootstrap._(cloudReadOnly: false);
      return _instance!;
    }
    final m = raw.readEditorBootstrapRaw();
    _instance = EditorBootstrap._(
      projectId: m['projectId'] as String?,
      projectName: m['projectName'] as String?,
      apiBaseOverride: m['apiBaseOverride'] as String?,
      cloudReadOnly: m['cloudReadOnly'] as bool? ?? false,
    );
    return _instance!;
  }

  final String? projectId;
  final String? projectName;
  final String? apiBaseOverride;
  final bool cloudReadOnly;

  bool get hasProjectContext => projectId != null && projectId!.isNotEmpty;
}
