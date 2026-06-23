import 'dart:convert';
import 'dart:io';

/// E21a — `.meta.json` v2 для ассетов (reimport, зависимости).
class LynxAssetMetaV2 {
  LynxAssetMetaV2({
    required this.assetPath,
    this.metaVersion = 2,
    this.guid,
    this.importer = 'lynx/default',
    this.sourceHash,
    this.dependencies = const [],
    this.labels = const [],
    this.extra = const {},
  });

  static const kMetaVersion = 2;

  final String assetPath;
  final int metaVersion;
  final String? guid;
  final String importer;
  final String? sourceHash;
  final List<String> dependencies;
  final List<String> labels;
  final Map<String, dynamic> extra;

  String get sidecarPath => '$assetPath.meta.json';

  static String sidecarPathFor(String assetPath) => '$assetPath.meta.json';

  Map<String, dynamic> toJson() => {
        'metaVersion': metaVersion,
        'guid': guid,
        'importer': importer,
        if (sourceHash != null) 'sourceHash': sourceHash,
        'dependencies': dependencies,
        'labels': labels,
        if (extra.isNotEmpty) 'extra': extra,
      };

  factory LynxAssetMetaV2.fromJson(Map<String, dynamic> json, {required String assetPath}) {
    return LynxAssetMetaV2(
      assetPath: assetPath,
      metaVersion: json['metaVersion'] as int? ?? 1,
      guid: json['guid'] as String?,
      importer: json['importer'] as String? ?? 'lynx/default',
      sourceHash: json['sourceHash'] as String?,
      dependencies: (json['dependencies'] as List?)?.cast<String>() ?? const [],
      labels: (json['labels'] as List?)?.cast<String>() ?? const [],
      extra: (json['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  LynxAssetMetaV2 bumpForReimport({required String newHash}) => LynxAssetMetaV2(
        assetPath: assetPath,
        metaVersion: kMetaVersion,
        guid: guid ?? _newGuid(assetPath),
        importer: importer,
        sourceHash: newHash,
        dependencies: dependencies,
        labels: labels,
        extra: extra,
      );

  static String _newGuid(String assetPath) =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${assetPath.hashCode.abs()}';
}

Future<LynxAssetMetaV2?> readAssetMetaV2({
  required String projectRoot,
  required String relativeAssetPath,
}) async {
  final file = File('$projectRoot/${LynxAssetMetaV2.sidecarPathFor(relativeAssetPath)}');
  if (!await file.exists()) return null;
  try {
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return LynxAssetMetaV2.fromJson(json, assetPath: relativeAssetPath);
  } catch (_) {
    return null;
  }
}

Future<void> writeAssetMetaV2({
  required String projectRoot,
  required LynxAssetMetaV2 meta,
}) async {
  final file = File('$projectRoot/${meta.sidecarPath}');
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(meta.toJson()));
}

/// Префаб v2 — ссылка на meta guid (E21b).
class LynxPrefabRefV2 {
  LynxPrefabRefV2({required this.prefabId, required this.metaGuid, this.variant});

  final String prefabId;
  final String metaGuid;
  final String? variant;

  Map<String, dynamic> toJson() => {
        'prefabId': prefabId,
        'metaGuid': metaGuid,
        if (variant != null) 'variant': variant,
      };

  factory LynxPrefabRefV2.fromJson(Map<String, dynamic> json) => LynxPrefabRefV2(
        prefabId: json['prefabId'] as String? ?? '',
        metaGuid: json['metaGuid'] as String? ?? '',
        variant: json['variant'] as String?,
      );
}
