class IntegrationRuntime {
  IntegrationRuntime._();

  static const String _production = 'http://72.56.244.26:8080';

  static String _stripTrailingSlash(String u) => u.replaceAll(RegExp(r'/$'), '');

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('INTEGRATION_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return _stripTrailingSlash(fromEnv);
    }
    return _production;
  }
}
