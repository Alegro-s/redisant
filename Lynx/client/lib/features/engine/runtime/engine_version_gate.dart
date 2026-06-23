import 'engine_binary_loader.dart';
import 'lynx_core_probe.dart';

/// Сравнение semver `1.2.3` (короткие версии дополняются нулями).
int compareEngineVersions(String a, String b) {
  List<int> parse(String v) {
    return v
        .split(RegExp(r'[.+-]'))
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  final pa = parse(a);
  final pb = parse(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final da = i < pa.length ? pa[i] : 0;
    final db = i < pb.length ? pb[i] : 0;
    if (da != db) return da.compareTo(db);
  }
  return 0;
}

class EngineVersionCheck {
  final bool ok;
  final String? message;
  const EngineVersionCheck({required this.ok, this.message});
}

class InstalledRuntimeVersions {
  final String? nexusEngine;
  final String? lynxCore;
  final int? lynxCoreApi;
  const InstalledRuntimeVersions({
    this.nexusEngine,
    this.lynxCore,
    this.lynxCoreApi,
  });

  String get displayLabel {
    final parts = <String>[];
    if (nexusEngine != null && nexusEngine!.isNotEmpty) {
      parts.add('Lynx Engine $nexusEngine');
    }
    if (lynxCore != null && lynxCore!.isNotEmpty) {
      final api = lynxCoreApi != null ? ' (API $lynxCoreApi)' : '';
      parts.add('Core $lynxCore$api');
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

/// Метка NEXUS из Hub/кэша + Lynx Core из загруженной `engine.dll` (волна 11d).
Future<InstalledRuntimeVersions> getInstalledRuntimeVersions() async {
  final nexus = await getInstalledEngineVersionLabel();
  final core = await probeInstalledLynxCore();
  return InstalledRuntimeVersions(
    nexusEngine: nexus,
    lynxCore: core?.version,
    lynxCoreApi: core?.apiVersion,
  );
}

/// Проверка `minNexusEngineVersion` из project.json (волна 4).
Future<EngineVersionCheck> checkProjectEngineVersion({
  required String? minRequired,
}) async {
  if (minRequired == null || minRequired.trim().isEmpty) {
    return const EngineVersionCheck(ok: true);
  }
  final installed = await getInstalledEngineVersionLabel();
  if (installed == null || installed.isEmpty) {
    return EngineVersionCheck(
      ok: false,
      message:
          'Проект требует Lynx Engine ≥ $minRequired. Установите версию в разделе «Lynx Engine».',
    );
  }
  if (compareEngineVersions(installed, minRequired) < 0) {
    return EngineVersionCheck(
      ok: false,
      message:
          'Установлено Lynx Engine $installed, проект требует ≥ $minRequired. Обновите движок.',
    );
  }
  return const EngineVersionCheck(ok: true);
}

/// Проверка `minLynxCoreVersion` (semver Lynx Core внутри engine, волна 11d).
Future<EngineVersionCheck> checkProjectLynxCoreVersion({
  required String? minRequired,
}) async {
  if (minRequired == null || minRequired.trim().isEmpty) {
    return const EngineVersionCheck(ok: true);
  }
  final core = await probeInstalledLynxCore();
  if (core == null) {
    return EngineVersionCheck(
      ok: false,
      message:
          'Проект требует Lynx Core ≥ $minRequired. Соберите engine (release) или установите ядро с Hub.',
    );
  }
  if (compareEngineVersions(core.version, minRequired) < 0) {
    return EngineVersionCheck(
      ok: false,
      message:
          'Установлен Lynx Core ${core.version}, проект требует ≥ $minRequired. Пересоберите engine или обновите ядро.',
    );
  }
  return const EngineVersionCheck(ok: true);
}

/// NEXUS + Lynx Core (нативный Play / Player).
Future<EngineVersionCheck> checkProjectRuntimeVersions({
  String? minNexusEngineVersion,
  String? minLynxCoreVersion,
}) async {
  final nexus = await checkProjectEngineVersion(minRequired: minNexusEngineVersion);
  if (!nexus.ok) return nexus;
  return checkProjectLynxCoreVersion(minRequired: minLynxCoreVersion);
}
