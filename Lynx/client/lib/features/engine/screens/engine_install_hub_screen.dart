import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../../auth/providers/auth_provider.dart';
import '../runtime/engine_binary_loader.dart';
import '../runtime/engine_version_gate.dart';

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
  List<String> _localVersions = const [];

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
      final runtime = await getInstalledRuntimeVersions();
      final local = await listInstalledLynxEngineVersions();
      if (!mounted) return;
      setState(() {
        _manifest = m;
        _localVersions = local;
        _loadErr = m == null && local.isEmpty && !kIsWeb
            ? 'Не удалось загрузить каталог версий. Импортируйте .lynxengine или проверьте интернет.'
            : null;
        _installedPath = p;
        _installedVer = runtime.displayLabel != '—'
            ? runtime.displayLabel
            : (local.isNotEmpty ? 'Lynx Engine ${local.first}' : null);
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

  Future<void> _importLocalPack() async {
    if (kIsWeb) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['lynxengine'],
      withData: true,
    );
    if (pick == null || pick.files.isEmpty) return;
    final bytes = pick.files.single.bytes;
    if (bytes == null) return;
    setState(() => _busyVersion = 'import');
    try {
      final path = await installLynxEngineFromBytes(bytes);
      if (!mounted) return;
      if (path != null) {
        final runtime = await getInstalledRuntimeVersions();
        setState(() {
          _installedPath = path;
          _installedVer = runtime.displayLabel;
          _busyVersion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lynx Engine установлен из .lynxengine')),
        );
      } else {
        setState(() => _busyVersion = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось распаковать .lynxengine')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyVersion = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _importFromInstallFolder() async {
    if (kIsWeb) return;
    final exeDir = File(Platform.resolvedExecutable).parent;
    final candidates = <File>[];
    for (final dir in [exeDir, Directory(p.join(exeDir.path, 'dist'))]) {
      if (!await dir.exists()) continue;
      await for (final ent in dir.list()) {
        if (ent is File && ent.path.toLowerCase().endsWith('.lynxengine')) {
          candidates.add(ent);
        }
      }
    }
    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Рядом с LynxLauncher.exe нет .lynxengine (проверьте папку dist/)'),
        ),
      );
      return;
    }
    final file = candidates.length == 1
        ? candidates.first
        : await showDialog<File>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: const Text('Импорт из папки установки'),
              children: [
                for (final f in candidates)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, f),
                    child: Text(p.basename(f.path)),
                  ),
              ],
            ),
          );
    if (file == null || !mounted) return;
    setState(() => _busyVersion = 'import');
    try {
      final bytes = await file.readAsBytes();
      final path = await installLynxEngineFromBytes(bytes);
      if (!mounted) return;
      if (path != null) {
        final runtime = await getInstalledRuntimeVersions();
        setState(() {
          _installedPath = path;
          _installedVer = runtime.displayLabel;
          _busyVersion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Установлено: ${p.basename(file.path)}')),
        );
        await _refresh();
      } else {
        setState(() => _busyVersion = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyVersion = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
        final runtime = await getInstalledRuntimeVersions();
        if (!mounted) return;
        setState(() {
          _installedPath = path;
          _installedVer = runtime.displayLabel;
          _busyVersion = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lynx Engine $version установлено')),
        );
      } else {
        setState(() => _busyVersion = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось скачать эту версию. Проверьте артефакт .lynxengine для вашей ОС в манифесте.',
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
        appBar: AppBar(title: const Text('Lynx Engine')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'В браузере ядро WASM уже загружено — отдельный .lynxengine не нужен.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.go('/workspace'),
                    child: const Text('Открыть редактор'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Центр ядер Lynx Engine'),
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
                        'Центр ядер Lynx Engine',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lynx Engine — отдельный продукт (файл .lynxengine). Устанавливается в %LOCALAPPDATA%\\Lynx\\engines\\. Launcher не включает engine.dll.',
                        style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _busyVersion != null ? null : _importLocalPack,
                        icon: const Icon(Icons.folder_open_outlined, size: 18),
                        label: const Text('Импорт .lynxengine'),
                      ),
                      const SizedBox(height: 14),
                      if (_installedVer != null)
                        SelectableText(
                          'Активная версия: $_installedVer\n${_installedPath ?? ''}',
                          style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600),
                        )
                      else if (_localVersions.isNotEmpty)
                        Text(
                          'На ПК: ${_localVersions.join(', ')}',
                          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                        )
                      else
                        Text(
                          'Движок не установлен — импортируйте .lynxengine или скачайте из каталога.',
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
                if (_localVersions.isNotEmpty) ...[
                  Text(
                    'Установлено на этом ПК',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  ..._localVersions.map(
                    (ver) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: cs.primaryContainer.withValues(alpha: 0.25),
                      child: ListTile(
                        leading: Icon(Icons.check_circle_rounded, color: cs.primary),
                        title: Text('Lynx Engine $ver', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('Готово к работе в редакторе и Play'),
                        trailing: IconButton(
                          tooltip: 'Удалить версию',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _busyVersion != null
                              ? null
                              : () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Удалить ядро?'),
                                      content: Text('Lynx Engine $ver будет удалён с диска.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                                      ],
                                    ),
                                  );
                                  if (ok != true) return;
                                  setState(() => _busyVersion = ver);
                                  await removeInstalledLynxEngineVersion(ver);
                                  if (mounted) await _refresh();
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Каталог версий',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (_manifest == null || _manifest!.releases.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _localVersions.isNotEmpty
                              ? 'Онлайн-каталог недоступен — используйте установленную версию или импорт .lynxengine.'
                              : 'Каталог пуст. Импортируйте Lynx-Engine-….lynxengine из дистрибутива.',
                          style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busyVersion != null ? null : _importFromInstallFolder,
                          icon: const Icon(Icons.install_desktop_outlined, size: 18),
                          label: const Text('Импорт из папки установки'),
                        ),
                      ],
                    ),
                  )
                else
                  ..._manifest!.releaseEntries.map((rel) {
                    final ver = rel.version;
                    final ok = engineReleaseSupportsCurrentHost(
                      _manifest!.releases.firstWhere(
                        (r) => r['version']?.toString() == ver,
                        orElse: () => rel.artifacts.isNotEmpty
                            ? {'version': ver, 'artifacts': rel.artifacts}
                            : {'version': ver},
                      ),
                    );
                    final rec = _manifest!.recommendedVersion == ver;
                    final busy = _busyVersion == ver;
                    final channel = rel.channel?.trim();
                    final subtitle = rel.displaySubtitle.isNotEmpty
                        ? rel.displaySubtitle
                        : (ok ? 'Есть артефакт для этой ОС' : 'Нет артефакта под вашу платформу');
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
                            if (channel != null && channel.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(channel, style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: channel == 'beta'
                                    ? cs.tertiary.withValues(alpha: 0.2)
                                    : cs.surfaceContainerHighest,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
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

  final localVersions = await listInstalledLynxEngineVersions();
  final cachedPath = await getLastCachedEngineLibraryPath();
  if (cachedPath != null || localVersions.isNotEmpty) {
    return await getInstalledEngineVersionLabel() ?? localVersions.firstOrNull;
  }

  final manifest = await fetchEngineManifestSnapshot(dio);
  if (!context.mounted) return null;

  final supported = manifest?.releases
          .where(engineReleaseSupportsCurrentHost)
          .map((r) => r['version']?.toString())
          .whereType<String>()
          .toList() ??
      [];

  if (supported.isEmpty) {
    final goHub = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нужен Lynx Engine'),
        content: const Text(
          'На сервере нет каталога для вашей ОС. Импортируйте файл .lynxengine '
          '(рядом с установщиком) в разделе «Lynx Engine».',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Открыть Lynx Engine')),
        ],
      ),
    );
    if (goHub == true && context.mounted) {
      await context.push('/engine-install');
      final again = await listInstalledLynxEngineVersions();
      if (again.isNotEmpty) return again.first;
      return getInstalledEngineVersionLabel();
    }
    return null;
  }
  String? chosen = manifest?.recommendedVersion;
  if (chosen == null || !supported.contains(chosen)) {
    chosen = supported.first;
  }

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      var localChosen = chosen;
      return StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Версия Lynx Engine'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Выберите версию Lynx Engine для проекта.',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: localChosen,
                    items: supported
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setS(() => localChosen = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Отмена')),
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
            Expanded(child: Text('Скачивание Lynx Engine…')),
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
          title: const Text('Lynx Engine не установлен'),
          content: const Text(
            'Проверьте сеть, артефакт .lynxengine для вашей ОС в манифесте или импортируйте файл в «Lynx Engine».',
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
