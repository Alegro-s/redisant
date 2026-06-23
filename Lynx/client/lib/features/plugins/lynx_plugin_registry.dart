import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'builtin/register_builtin_plugins.dart';
import 'lynx_plugin_contract.dart';
import 'lynx_plugin_manifest.dart';

/// Глобальный реестр известных плагинов (builtin + из папки проекта).
class LynxPluginRegistry {
  LynxPluginRegistry._();

  static final LynxPluginRegistry instance = LynxPluginRegistry._();

  final Map<String, LynxClientPlugin> _builtins = {};
  final Map<String, LynxPluginManifest> _manifests = {};

  bool _initialized = false;

  void ensureInitialized() {
    if (_initialized) return;
    registerBuiltinPlugins(this);
    _initialized = true;
  }

  void registerBuiltin(LynxClientPlugin plugin) {
    final id = plugin.manifest.id;
    _builtins[id] = plugin;
    _manifests[id] = plugin.manifest;
  }

  void registerManifest(LynxPluginManifest manifest) {
    _manifests[manifest.id] = manifest;
  }

  LynxClientPlugin? builtin(String id) => _builtins[id];

  LynxPluginManifest? manifest(String id) => _manifests[id];

  Iterable<LynxPluginManifest> get allManifests => _manifests.values;

  /// Скан `{projectRoot}/plugins/*/lynx.plugin.json`.
  Future<void> discoverProjectPlugins(String? projectRoot) async {
    if (projectRoot == null || projectRoot.isEmpty) return;
    final pluginsDir = Directory(p.join(projectRoot, 'plugins'));
    if (!await pluginsDir.exists()) return;
    await for (final entity in pluginsDir.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, 'lynx.plugin.json'));
      if (!await manifestFile.exists()) continue;
      try {
        final raw =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        final manifest = LynxPluginManifest.fromJson(raw);
        if (manifest.id.isEmpty) continue;
        registerManifest(manifest);
      } catch (_) {}
    }
  }

  List<LynxClientPlugin> resolveEnabled(LynxProjectPlugins projectPlugins) {
    ensureInitialized();
    final out = <LynxClientPlugin>[];
    for (final id in projectPlugins.enabled) {
      final plugin = _builtins[id];
      if (plugin != null) {
        out.add(plugin);
      }
    }
    return out;
  }
}
