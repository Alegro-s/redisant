import 'package:flutter/foundation.dart';

class IntegrationRuntime {
  IntegrationRuntime._();

  static const String _production = 'http://72.56.244.26:8080';
  static const String _localDev = 'http://127.0.0.1:8080';

  static String _stripTrailingSlash(String u) => u.replaceAll(RegExp(r'/$'), '');

  
  static bool get useSupabaseDirect {
    const override = String.fromEnvironment('USE_SUPABASE_DIRECT', defaultValue: '');
    if (override == 'true') return true;
    if (override == 'false') return false;
    const apiUrl = String.fromEnvironment('INTEGRATION_BASE_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) return false;
    return !kDebugMode;
  }

  static String get baseUrl {
    if (useSupabaseDirect) {
      return _stripTrailingSlash(_localDev);
    }
    const fromEnv = String.fromEnvironment(
      'INTEGRATION_BASE_URL',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) {
      return _stripTrailingSlash(fromEnv);
    }
    if (kDebugMode) {
      return _localDev;
    }
    return _production;
  }
}
