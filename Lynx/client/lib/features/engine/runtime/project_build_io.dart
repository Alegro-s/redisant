import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'embedded_game_pack_io.dart';
import 'lynx_export_io.dart';

/// Быстрый экспорт `game_data` (совместимость с меню «Сборка game_data»).
Future<String?> exportDesktopProjectBundle({
  required String projectRoot,
  required String outputDirectory,
  String? engineLibraryAbsolutePath,
}) async {
  return runLynxExport(
    projectRoot: projectRoot,
    outputDirectory: outputDirectory,
    preset: LynxExportPreset.dataBundle,
    engineLibraryAbsolutePath: engineLibraryAbsolutePath,
  );
}
