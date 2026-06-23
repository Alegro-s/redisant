import 'lynx_export.dart';

/// E22a — профили сборки (Win / APK / Web / Cart).
enum LynxBuildProfile {
  windows,
  android,
  web,
  cart,
  dataBundle;

  static LynxBuildProfile fromExportPreset(LynxExportPreset preset) => switch (preset) {
        LynxExportPreset.windows => LynxBuildProfile.windows,
        LynxExportPreset.android => LynxBuildProfile.android,
        LynxExportPreset.web => LynxBuildProfile.web,
        LynxExportPreset.cart => LynxBuildProfile.cart,
        LynxExportPreset.dataBundle => LynxBuildProfile.dataBundle,
      };
}

extension LynxBuildProfileX on LynxBuildProfile {
  String get label => switch (this) {
        LynxBuildProfile.windows => 'Windows EXE',
        LynxBuildProfile.android => 'Android APK',
        LynxBuildProfile.web => 'Web (статика)',
        LynxBuildProfile.cart => 'Lynx Cart (.lynxcart)',
        LynxBuildProfile.dataBundle => 'game_data',
      };

  LynxExportPreset get exportPreset => switch (this) {
        LynxBuildProfile.windows => LynxExportPreset.windows,
        LynxBuildProfile.android => LynxExportPreset.android,
        LynxBuildProfile.web => LynxExportPreset.web,
        LynxBuildProfile.cart => LynxExportPreset.cart,
        LynxBuildProfile.dataBundle => LynxExportPreset.dataBundle,
      };

  /// E22b — шаги прогресса N/M.
  int get progressSteps => switch (this) {
        LynxBuildProfile.android => 6,
        LynxBuildProfile.windows => 5,
        LynxBuildProfile.web => 4,
        LynxBuildProfile.cart => 3,
        LynxBuildProfile.dataBundle => 2,
      };

}
