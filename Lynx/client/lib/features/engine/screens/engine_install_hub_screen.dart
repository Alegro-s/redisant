import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../runtime/engine_binary_loader.dart';

class EngineInstallHubScreen extends StatefulWidget {
  const EngineInstallHubScreen({super.key});

  @override
  State<EngineInstallHubScreen> createState() => _EngineInstallHubScreenState();
}

class _EngineInstallHubScreenState extends State<EngineInstallHubScreen> {
  NexusEngineManifestSnapshot? _manifest;
  String? _loadErr;
  bool _loading = true;
  String? _busyVersion;
  String? _installedPath;
  String? _installedVer;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadErr = null;
    });
    final auth = context.read<AuthProvider>();
    try {
      final m = await fetchEngineManifestSnapshot(auth.http);
      final p = await getLastCachedEngineLibraryPath();
      final v = await getInstalledEngineVersionLabel();
      if (!mounted) return;
      setState(() {
        _manifest = m;
        _loadErr = m == null && !kIsWeb ? 'Не удалось загрузить /engine/manifest (сеть или пустая политика на сервере).' : null;
        _installedPath = p;
        _installedVer = v;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadErr = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _download(String version) async {
    if (kIsWeb) return;
    setState(() => _busyVersion = version);
    final auth = context.read<AuthProvider>();
    try {
      final path = await ensureEngineBinary(auth.http, preferredVersion: version);
      if (!mounted) return;
      if (path != null) {
        final v = await getInstalledEngineVersionLabel();
        if (!mounted) return;
        setState(() {
          _installedPath = path;
          _installedVer = v;
          _busyVersion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ядро $version установлено')),
        );
      } else {
        setState(() => _busyVersion = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось скачать эту версию. Проверьте артефакт для вашей ОС в манифесте и авторизацию для шифрованного .nexus.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyVersion = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ядро NEXUS')),
        body: const Center(child: Text('В браузере нативное ядро не устанавливается. Используйте десктоп-клиент.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ядро NEXUS'),
        actions: [
          IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primaryContainer.withValues(alpha: 0.35),
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Нативное ядро',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Библиотека Rust (engine.dll / libengine.so) кэшируется локально. Версии и хеши задаются манифестом API; зашифрованные пакеты загружаются после POST /me/engine/session.',
                        style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      if (_installedVer != null)
                        SelectableText(
                          'Активная версия: $_installedVer\n${_installedPath ?? ''}',
                          style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600),
                        )
                      else
                        Text(
                          'Ядро ещё не установлено — выберите версию ниже.',
                          style: TextStyle(color: cs.tertiary, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                if (_loadErr != null) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: cs.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_loadErr!, style: TextStyle(color: cs.onErrorContainer)),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  'Доступные релизы',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_manifest == null || _manifest!.releases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Манифест пуст. Задайте NEXUS_ENGINE_MANIFEST_JSON на сервере или URL в админке (политика engine).',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  ..._manifest!.releases.map((rel) {
                    final ver = rel['version']?.toString() ?? '?';
                    final notes = rel['notes']?.toString();
                    final ok = engineReleaseSupportsCurrentHost(rel);
                    final rec = _manifest!.recommendedVersion == ver;
                    final busy = _busyVersion == ver;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(ver, style: const TextStyle(fontWeight: FontWeight.w800)),
                            if (rec) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: const Text('рекомендуется', style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: cs.primary.withValues(alpha: 0.2),
                              ),
                            ],
                          ],
                        ),
                        subtitle: notes != null && notes.isNotEmpty
                            ? Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis)
                            : Text(ok ? 'Есть артефакт для этой ОС' : 'Нет артефакта под вашу платформу в манифесте'),
                        trailing: busy
                            ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                            : FilledButton(
                                onPressed: ok ? () => _download(ver) : null,
                                child: const Text('Установить'),
                              ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Text(
                  'Источник манифеста: ${_manifest?.source ?? '—'}',
                  style: TextStyle(fontSize: 11, color: cs.outline),
                ),
              ],
            ),
    );
  }
}

Future<String?> showEngineVersionInstallDialog(BuildContext context, Dio dio) async {
  if (kIsWeb) return null;
  final existing = await getLastCachedEngineLibraryPath();
  if (existing != null) {
    return await getInstalledEngineVersionLabel();
  }

  final manifest = await fetchEngineManifestSnapshot(dio);
  if (!context.mounted) return null;

  final supported = manifest?.releases
          .where(engineReleaseSupportsCurrentHost)
          .map((r) => r['version']?.toString())
          .whereType<String>()
          .toList() ??
      [];

  String? chosen = manifest?.recommendedVersion;
  if (chosen == null || !supported.contains(chosen)) {
    chosen = supported.isNotEmpty ? supported.first : null;
  }

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      var localChosen = chosen;
      return StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Версия ядра'),
            content: SizedBox(
              width: 420,
              child: supported.isEmpty
                  ? const Text(
                      'В манифесте нет релиза с артефактом для вашей ОС. Откройте «Центр ядра» из списка проектов или проверьте /engine/manifest.',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Выберите версию Rust-ядра для студии (как выбор версии Editor в Unity).',
                          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        DropdownButton<String>(
                          isExpanded: true,
                          value: localChosen,
                          hint: const Text('Версия'),
                          items: supported
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setS(() => localChosen = v),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Отмена')),
              if (supported.isNotEmpty)
                FilledButton(
                  onPressed: localChosen == null ? null : () => Navigator.pop(ctx, localChosen),
                  child: const Text('Скачать и продолжить'),
                ),
            ],
          );
        },
      );
    },
  );

  if (result == null || !context.mounted) return null;

  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Скачивание ядра…')),
          ],
        ),
      ),
    ),
  );

  try {
    final path = await ensureEngineBinary(dio, preferredVersion: result);
    nav.pop();
    if (!context.mounted) return null;
    if (path == null) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ядро не установлено'),
          content: const Text(
            'Проверьте сеть, артефакт для вашей ОС в манифесте и (для .nexus) вход в аккаунт.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      return null;
    }
    return getInstalledEngineVersionLabel();
  } catch (e) {
    nav.pop();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    return null;
  }
}
