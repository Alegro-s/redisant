/// Shared export types (no dart:io — safe for web).
enum LynxExportPreset {
  windows,
  web,
  android,
  cart,
  dataBundle,
}

class LynxExportResult {
  final LynxExportPreset preset;
  final String outputDirectory;
  final List<String> artifactPaths;
  const LynxExportResult({
    required this.preset,
    required this.outputDirectory,
    required this.artifactPaths,
  });
}
