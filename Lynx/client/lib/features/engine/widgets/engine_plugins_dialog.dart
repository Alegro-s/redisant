import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/providers/settings_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ecosystem/lynx_marketplace.dart';
import '../../plugins/lynx_plugin_host.dart';
import '../../plugins/lynx_plugin_manifest.dart';
import '../models/engine_models.dart';
import '../project_manager.dart';

/// Включение плагинов, ассетов и установка из Lynx Cloud.
class EnginePluginsDialog extends StatefulWidget {
  const EnginePluginsDialog({super.key, required this.manager});

  final ProjectManager manager;

  @override
  State<EnginePluginsDialog> createState() => _EnginePluginsDialogState();
}

class _EnginePluginsDialogState extends State<EnginePluginsDialog> {
  late LynxProjectMode _mode;
  late Set<String> _enabled;
  late Set<String> _disabledAssets;
  late Map<String, Map<String, dynamic>> _config;
  LynxMarketplaceCatalog? _catalog;
  bool _loadingCatalog = false;
  String? _catalogError;

  @override
  void initState() {
    super.initState();
    final p = widget.manager.projectSettings!;
    _mode = p.projectMode;
    _enabled = Set<String>.from(p.lynxPlugins.enabled);
    _disabledAssets = Set<String>.from(p.lynxPlugins.disabledAssetPaths);
    _config = p.lynxPlugins.config.map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
    );
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _catalogError = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final url = context.read<SettingsProvider>().storeCatalogUrl.trim();
      final cat = await LynxMarketplace.fetchCatalog(
        url,
        cloudDio: auth.isAuthenticated ? auth.http : null,
      );
      if (!mounted) return;
      setState(() {
        _catalog = cat;
        _loadingCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _catalogError = '$e';
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _installItem(LynxMarketplaceItem item) async {
    final root = widget.manager.rootPath;
    if (root == null) return;
    final repoRoot = Directory(root).parent.path;
    final auth = context.read<AuthProvider>();
    final result = await LynxMarketplace.installIntoProject(
      projectRoot: root,
      item: item,
      repoRoot: repoRoot,
      cloudDio: auth.isAuthenticated ? auth.http : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    if (result.ok) {
      final root = widget.manager.rootPath;
      if (root != null) await widget.manager.loadProject(root);
      final p = widget.manager.projectSettings;
      if (p != null) {
        setState(() {
          _enabled.addAll(p.lynxPlugins.enabled);
        });
      }
    }
  }

  Future<void> _save() async {
    final base = widget.manager.projectSettings!;
    final plugins = LynxProjectPlugins(
      enabled: _enabled.toList()..sort(),
      disabledAssetPaths: _disabledAssets.toList()..sort(),
      config: _config,
    );
    var mode = _mode;
    if (_enabled.contains(Lynx3dPluginIds.pluginId) && mode == LynxProjectMode.d2) {
      mode = LynxProjectMode.d3;
    }
    await widget.manager.saveProjectSettings(
      base.copyWith(projectMode: mode, lynxPlugins: plugins),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final manifests = LynxPluginHost.instance.availableManifests();
    final assets = widget.manager.assets;
    final pluginsFromStore = (_catalog?.items ?? const [])
        .where((i) => i.kind == 'plugin')
        .toList();

    return AlertDialog(
      title: const Text('Плагины и ассеты'),
      content: SizedBox(
        width: 520,
        height: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Плагины и пакеты ассетов хранятся в папке проекта. '
                'Отключение не удаляет файлы — только скрывает из сборки.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LynxProjectMode>(
                value: _mode,
                decoration: const InputDecoration(
                  labelText: 'Режим проекта',
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: LynxProjectMode.d2, child: Text('2D')),
                  DropdownMenuItem(value: LynxProjectMode.d3, child: Text('3D')),
                  DropdownMenuItem(value: LynxProjectMode.hybrid, child: Text('Hybrid')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _mode = v);
                },
              ),
              const SizedBox(height: 16),
              const Text('Плагины проекта', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (manifests.isEmpty)
                const Text('Нет плагинов в plugins/.')
              else
                for (final m in manifests)
                  CheckboxListTile(
                    value: _enabled.contains(m.id),
                    onChanged: (on) {
                      setState(() {
                        if (on == true) {
                          _enabled.add(m.id);
                        } else {
                          _enabled.remove(m.id);
                        }
                      });
                    },
                    title: Text(m.name),
                    subtitle: Text(
                      '${m.id} v${m.version}'
                      '${m.description != null ? '\n${m.description}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: Icon(
                      m.id == Lynx3dPluginIds.pluginId
                          ? Icons.view_in_ar_outlined
                          : Icons.extension_outlined,
                    ),
                    dense: true,
                  ),
              if (_enabled.contains(Lynx3dPluginIds.pluginId)) ...[
                const Divider(),
                DropdownButtonFormField<String>(
                  value: (_config[Lynx3dPluginIds.pluginId]?['defaultCamera'] as String?) ??
                      'perspective',
                  decoration: const InputDecoration(labelText: 'Камера 3D', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'perspective', child: Text('Perspective')),
                    DropdownMenuItem(value: 'orthographic', child: Text('Orthographic')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _config[Lynx3dPluginIds.pluginId] = {
                        ...?_config[Lynx3dPluginIds.pluginId],
                        'defaultCamera': v,
                      };
                    });
                  },
                ),
              ],
              const Divider(height: 24),
              const Text('Ассеты проекта', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (assets.isEmpty)
                const Text('Нет файлов в assets/.')
              else
                for (final a in assets.take(40))
                  SwitchListTile(
                    dense: true,
                    title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      a.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: !_disabledAssets.contains(a.path.replaceAll('\\', '/')),
                    onChanged: (on) {
                      final norm = a.path.replaceAll('\\', '/');
                      setState(() {
                        if (on == true) {
                          _disabledAssets.remove(norm);
                        } else {
                          _disabledAssets.add(norm);
                        }
                      });
                    },
                  ),
              if (assets.length > 40)
                Text(
                  '… и ещё ${assets.length - 40} (откройте папку assets)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Text('Lynx Cloud', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined, size: 20),
                    onPressed: _loadingCatalog ? null : _loadCatalog,
                  ),
                ],
              ),
              if (_loadingCatalog)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_catalogError != null)
                Text(_catalogError!, style: TextStyle(color: Theme.of(context).colorScheme.error))
              else if (pluginsFromStore.isEmpty)
                const Text('Нет плагинов в каталоге.')
              else
                for (final item in pluginsFromStore.take(8))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.download_outlined),
                    title: Text(item.title),
                    subtitle: Text(
                      item.description ?? item.id,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () => _installItem(item),
                      child: const Text('В проект'),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _save, child: const Text('Сохранить')),
      ],
    );
  }
}
