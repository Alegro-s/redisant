import 'package:flutter/foundation.dart';

/// URL облачного редактора Lynx (Launcher + браузер).
class LynxCloudUrls {
  LynxCloudUrls._();

  static const hubOrigin = 'https://lynx-hub.ru';

  /// Web Engine: `?project=cloud:<uuid>`.
  static String engineWeb({
    required String projectId,
    String? projectName,
    String hubBase = hubOrigin,
    bool readOnly = false,
  }) {
    final base = hubBase.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/engine-web').replace(queryParameters: {
      'project': 'cloud:$projectId',
      if (projectName != null && projectName.trim().isNotEmpty)
        'projectName': projectName.trim(),
      if (readOnly) 'readOnly': '1',
    }).toString();
  }

  /// In-app route (Flutter Web Launcher / PWA).
  static String engineWebRoute({
    required String projectId,
    String? projectName,
    bool readOnly = false,
  }) {
    return Uri(path: '/engine-web', queryParameters: {
      'project': 'cloud:$projectId',
      if (projectName != null && projectName.trim().isNotEmpty)
        'projectName': projectName.trim(),
      if (readOnly) 'readOnly': '1',
    }).toString();
  }
}
