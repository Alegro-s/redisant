class NexusPlaySnapshot {
  static const String nexusDir = '.nexus';
  static const String fileName = 'play_snapshot.json';

  static Future<void> ensureNexusDir(String projectRoot) async {}

  static Future<bool> exists(String projectRoot) async => false;

  static Future<String?> readOrNull(String projectRoot) async => null;

  static Future<void> write(String projectRoot, String engineJson) async {}

  static Future<String?> loadEngineJsonOrNull(String projectRoot) async => null;

  static Future<void> clear(String projectRoot) async {}
}
