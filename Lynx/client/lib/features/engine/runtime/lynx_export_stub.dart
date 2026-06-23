import 'lynx_export_io.dart' show LynxExportPreset, LynxExportResult;

Future<String?> runLynxExport({
  required String projectRoot,
  required String outputDirectory,
  required LynxExportPreset preset,
  String? engineLibraryAbsolutePath,
  String? clientRootForWebStaging,
}) async {
  return 'Экспорт доступен только на десктопе (Windows/macOS/Linux)';
}
