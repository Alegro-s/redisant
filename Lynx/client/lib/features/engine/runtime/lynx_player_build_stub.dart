import 'lynx_export_io.dart';

typedef LynxBuildLog = void Function(String message);

Future<String?> resolveLynxClientRoot({String? projectRoot}) async => null;

Future<String?> buildWindowsGameRelease({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
  LynxBuildLog? onLog,
}) async =>
    'Полная сборка Windows недоступна в веб-версии';

Future<String?> buildAndroidGameRelease({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
  LynxBuildLog? onLog,
}) async =>
    'Полная сборка APK недоступна в веб-версии';

Future<String?> runLynxFullBuild({
  required String projectRoot,
  required String outputDirectory,
  required LynxExportPreset preset,
  String? engineLibraryAbsolutePath,
  LynxBuildLog? onLog,
}) async =>
    runLynxExport(
      projectRoot: projectRoot,
      outputDirectory: outputDirectory,
      preset: preset,
      engineLibraryAbsolutePath: engineLibraryAbsolutePath,
    );
