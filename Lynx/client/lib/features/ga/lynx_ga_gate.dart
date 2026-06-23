/// Wave 32 — Lynx 1.0 GA version gate.
class LynxGaGate {
  static const launcherVersion = '1.0.0';
  static const engineCoreVersion = '1.0.0';
  static const engineApiVersion = 5;

  static bool isGaLauncher(String? version) {
    if (version == null || version.isEmpty) return false;
    return _parseSemver(version) >= _parseSemver(launcherVersion);
  }

  static bool isGaEngineCore(String? version) {
    if (version == null || version.isEmpty) return false;
    return _parseSemver(version) >= _parseSemver(engineCoreVersion);
  }

  static int _parseSemver(String v) {
    final parts = v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts[0] * 10000 + parts[1] * 100 + parts[2];
  }
}
