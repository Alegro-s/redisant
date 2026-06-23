import 'lynx_plugin_capability.dart';

/// Настройки плагинов в `project.json` → `lynxPlugins`.
class LynxProjectPlugins {
  static const int currentApiVersion = 1;

  final int apiVersion;
  final List<String> enabled;
  final List<String> disabledAssetPaths;
  final Map<String, Map<String, dynamic>> config;

  const LynxProjectPlugins({
    this.apiVersion = currentApiVersion,
    this.enabled = const [],
    this.disabledAssetPaths = const [],
    this.config = const {},
  });

  bool get is3dEnabled => enabled.contains(Lynx3dPluginIds.pluginId);

  Map<String, dynamic> toJson() => {
        'apiVersion': apiVersion,
        'enabled': List<String>.from(enabled),
        if (disabledAssetPaths.isNotEmpty)
          'disabledAssetPaths': List<String>.from(disabledAssetPaths),
        if (config.isNotEmpty)
          'config': config.map(
            (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
          ),
      };

  factory LynxProjectPlugins.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const LynxProjectPlugins();
    final cfgRaw = json['config'] as Map?;
    final config = <String, Map<String, dynamic>>{};
    if (cfgRaw != null) {
      for (final e in cfgRaw.entries) {
        final v = e.value;
        if (v is Map) {
          config[e.key.toString()] = Map<String, dynamic>.from(v);
        }
      }
    }
    return LynxProjectPlugins(
      apiVersion: (json['apiVersion'] as num?)?.toInt() ?? currentApiVersion,
      enabled: (json['enabled'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      disabledAssetPaths:
          (json['disabledAssetPaths'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      config: config,
    );
  }

  LynxProjectPlugins copyWith({
    int? apiVersion,
    List<String>? enabled,
    List<String>? disabledAssetPaths,
    Map<String, Map<String, dynamic>>? config,
  }) {
    return LynxProjectPlugins(
      apiVersion: apiVersion ?? this.apiVersion,
      enabled: enabled ?? this.enabled,
      disabledAssetPaths: disabledAssetPaths ?? this.disabledAssetPaths,
      config: config ?? this.config,
    );
  }
}

/// Режим проекта (2D ядро + опциональные плагины).
enum LynxProjectMode {
  d2('2d'),
  d3('3d'),
  hybrid('hybrid'),
  tic('tic');

  const LynxProjectMode(this.jsonValue);
  final String jsonValue;

  static LynxProjectMode fromJson(String? raw) {
    switch (raw) {
      case '3d':
        return LynxProjectMode.d3;
      case 'hybrid':
        return LynxProjectMode.hybrid;
      case 'tic':
        return LynxProjectMode.tic;
      default:
        return LynxProjectMode.d2;
    }
  }
}

/// Манифест `lynx.plugin.json` в папке плагина.
class LynxPluginManifest {
  final String id;
  final String name;
  final String version;
  final int apiVersion;
  final String? description;
  final List<LynxPluginCapability> capabilities;
  final String? sceneExtensionKey;
  final String? objectPropertyKey;
  final String? optionalNativeLib;
  final String? builtinId;

  const LynxPluginManifest({
    required this.id,
    required this.name,
    required this.version,
    this.apiVersion = 1,
    this.description,
    this.capabilities = const [],
    this.sceneExtensionKey,
    this.objectPropertyKey,
    this.optionalNativeLib,
    this.builtinId,
  });

  bool get isApiCompatible => apiVersion == LynxProjectPlugins.currentApiVersion;

  bool has(LynxPluginCapability cap) => capabilities.contains(cap);

  factory LynxPluginManifest.fromJson(Map<String, dynamic> json) {
    final capsRaw = json['capabilities'] as List? ?? const [];
    final caps = <LynxPluginCapability>[];
    for (final c in capsRaw) {
      final parsed = LynxPluginCapability.tryParse(c.toString());
      if (parsed != null) caps.add(parsed);
    }
    final engine = json['engine'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;
    return LynxPluginManifest(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '0.0.0',
      apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 1,
      description: json['description'] as String?,
      capabilities: caps,
      sceneExtensionKey: engine?['sceneExtensionKey'] as String?,
      objectPropertyKey: engine?['objectPropertyKey'] as String?,
      optionalNativeLib: engine?['optionalNativeLib'] as String?,
      builtinId: client?['builtinId'] as String?,
    );
  }
}

/// Константы плагина 3D (дублируют `plugins/lynx_3d/lynx.plugin.json`).
abstract final class Lynx3dPluginIds {
  static const pluginId = 'lynx.3d';
  static const sceneExtensionKey = 'lynx.3d';
  static const objectPropertyKey = 'lynx.3d';
}
