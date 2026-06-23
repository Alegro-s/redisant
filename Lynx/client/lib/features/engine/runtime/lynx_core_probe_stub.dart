class LynxCoreProbeResult {
  final String version;
  final int apiVersion;
  const LynxCoreProbeResult({required this.version, required this.apiVersion});
}

Future<LynxCoreProbeResult?> probeInstalledLynxCore() async => null;

Future<LynxCoreProbeResult?> probeLynxCoreFromLibrary(String libraryPath) async =>
    null;
