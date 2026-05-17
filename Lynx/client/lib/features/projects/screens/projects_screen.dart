import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:client/app/themes/nexus_theme.dart';

import '../../engine/runtime/project_zip_import_io.dart';
import '../../engine/screens/engine_install_hub_screen.dart';
import '../../engine/runtime/engine_binary_loader.dart';
import '../../engine/models/engine_models.dart';
import '../../../app/themes/nexus_shell_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../models/project.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final _slugCtrl = TextEditingController();
  bool _cloudLoaded = false;
  bool _localLoaded = false;
  final List<_LocalProjectEntry> _localProjects = [];

  static const String _kLocalProjectsKey = 'nexus.local_projects_v1';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLocalProjects();
        _loadEngineStatus();
      });
    }
  }

  String? _engineStatusLine;

  Future<void> _loadEngineStatus() async {
    if (kIsWeb) return;
    final p = await getLastCachedEngineLibraryPath();
    final v = await getInstalledEngineVersionLabel();
    if (!mounted) return;
    setState(() {
      _engineStatusLine =
          p != null ? 'Установлено: ${v ?? 'версия ?'}' : 'Не установлено — нужен engine.dll / libengine.so';
    });
  }

  @override
  void dispose() {
    _slugCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLocalProjects({bool force = false}) async {
    if (_localLoaded && !force) return;
    if (force) _localLoaded = false;
    _localLoaded = true;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalProjectsKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      final list = decoded is List ? decoded : <dynamic>[];
      final out = <_LocalProjectEntry>[];
      for (final e in list) {
        if (e is! Map) continue;
        final p = e['path']?.toString() ?? '';
        final name = e['name']?.toString() ?? '';
        final at = e['updatedAt'] is int
            ? e['updatedAt'] as int
            : int.tryParse(e['updatedAt']?.toString() ?? '') ?? 0;
        if (p.isEmpty || name.isEmpty) continue;
        final dir = Directory(p);
        if (!await dir.exists()) continue;
        out.add(
          _LocalProjectEntry(
            path: p,
            name: name,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(at),
          ),
        );
      }
      out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (mounted) setState(() => _localProjects..clear()..addAll(out));
    } catch (_) {
    }
  }

  Future<void> _rememberLocalProject({
    required String projectPath,
    required String projectName,
  }) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLocalProjectsKey);
    final list = <Map<String, dynamic>>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is Map) {
              final p = e['path']?.toString() ?? '';
              if (p.isEmpty) continue;
              list.add(Map<String, dynamic>.from(e as Map));
            }
          }
        }
      } catch (_) {}
    }

    list.removeWhere((e) => (e['path']?.toString() ?? '') == projectPath);
    list.insert(
      0,
      {
        'path': projectPath,
        'name': projectName,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (list.length > 20) {
      list.removeRange(20, list.length);
    }
    await prefs.setString(_kLocalProjectsKey, jsonEncode(list));

    final entry = _LocalProjectEntry(
      path: projectPath,
      name: projectName,
      updatedAt: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _localProjects.removeWhere((e) => e.path == projectPath);
        _localProjects.insert(0, entry);
        if (_localProjects.length > 20) _localProjects.removeRange(20, _localProjects.length);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cloudLoaded) return;
    _cloudLoaded = true;
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final err = await context.read<ProjectProvider>().loadProjects();
        if (mounted && err != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(err)));
        }
      });
    }
  }

  Future<void> _createOfflineProject(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Локальный проект недоступен в браузере')),
      );
      return;
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;
    if (!context.mounted) return;

    final nameController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Локальный проект'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Данные только на этом компьютере, без синхронизации с сервером.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Имя папки / проекта',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      final auth = context.read<AuthProvider>();
      final engineOk = await showEngineVersionInstallDialog(context, auth.http);
      if (engineOk == null) {
        return;
      }
      if (!context.mounted) return;
      final projectPath = path.join(selectedDirectory, nameController.text);
      final projectDir = Directory(projectPath);
      if (await projectDir.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Папка уже существует')));
        }
        return;
      }
      await projectDir.create(recursive: true);
      await Directory(
        path.join(projectPath, 'assets', 'sprites'),
      ).create(recursive: true);
      await Directory(
        path.join(projectPath, 'assets', 'scripts'),
      ).create(recursive: true);
      await Directory(
        path.join(projectPath, 'assets', 'sounds'),
      ).create(recursive: true);
      await Directory(path.join(projectPath, 'scenes')).create(recursive: true);
      await File(
        path.join(projectPath, 'scenes', 'main.json'),
      ).writeAsString('{"entities":[], "next_id":0}');
      final rec = await fetchRecommendedEngineVersion(auth.http);
      final bound = await getInstalledEngineVersionLabel();
      final gp = GameProject(
        projectId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        displayName: nameController.text.trim(),
        minNexusEngineVersion: rec,
        studioEngineBoundVersion: bound,
      );
      await File(path.join(projectPath, 'project.json')).writeAsString(jsonEncode(gp.toJson()));
      await Directory(path.join(projectPath, '.nexus')).create(recursive: true);
      await File(path.join(projectPath, '.nexus', 'engine_lock.json')).writeAsString(
        jsonEncode({
          'format': 'nexus_engine_lock',
          'schema': 1,
          'boundEngineVersion': bound ?? rec ?? 'unknown',
          'boundAt': DateTime.now().toUtc().toIso8601String(),
          'manifestRecommendedAtCreate': rec,
        }),
      );
      await File(path.join(projectPath, 'project.nexus')).writeAsString(
        '{"name":"${nameController.text}","version":"1.0.0","local":true}',
      );
      await _rememberLocalProject(
        projectPath: projectPath,
        projectName: nameController.text.trim(),
      );
      await _loadEngineStatus();
      if (context.mounted) {
        context.push(
          '/engine',
          extra: {
            'projectPath': projectPath,
            'projectName': nameController.text,
            'mode': 'offline',
          },
        );
      }
    }
  }

  Future<bool> _ensureNativeEngineOrPrompt(BuildContext context) async {
    if (kIsWeb) return true;
    if (await getLastCachedEngineLibraryPath() != null) return true;
    if (!context.mounted) return false;
    final install = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нужно ядро NEXUS'),
        content: const Text(
          'Для редактора и предпросмотра на ПК установите нативную библиотеку Rust. Открыть центр установки?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Установить')),
        ],
      ),
    );
    if (install == true && context.mounted) {
      await context.push('/engine-install');
    }
    return await getLastCachedEngineLibraryPath() != null;
  }

  Future<void> _openProjectFolder(BuildContext context) async {
    if (kIsWeb) return;
    if (!await _ensureNativeEngineOrPrompt(context)) return;
    if (!context.mounted) return;
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Папка с project.json',
    );
    if (dir == null || !context.mounted) return;
    final pj = File(path.join(dir, 'project.json'));
    if (!await pj.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Нет project.json — выберите корень проекта NEXUS (скачанный или экспортированный)',
            ),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await _rememberLocalProject(
      projectPath: dir,
      projectName: path.basename(dir),
    );
    context.push(
      '/engine',
      extra: {
        'projectPath': dir,
        'projectName': path.basename(dir),
        'mode': 'offline',
      },
    );
  }

  Future<void> _importProjectZip(BuildContext context) async {
    if (kIsWeb) return;
    if (!await _ensureNativeEngineOrPrompt(context)) return;
    if (!context.mounted) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    if (pick == null || pick.files.single.path == null) return;
    final zipPath = pick.files.single.path!;
    final parent = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Распаковать проект сюда',
    );
    if (parent == null || !context.mounted) return;
    final baseName = path.basenameWithoutExtension(zipPath);
    var dest = Directory(path.join(parent, baseName));
    if (await dest.exists()) {
      dest = Directory(
        path.join(
          parent,
          '${baseName}_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );
    }
    await dest.create(recursive: true);
    final err = await extractZipArchiveToDirectory(
      zipFile: File(zipPath),
      destinationDirectory: dest,
    );
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final root = await findNexusProjectRoot(dest.path);
    if (!context.mounted) return;
    if (root == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('В архиве не найден project.json: ${dest.path}'),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await _rememberLocalProject(
      projectPath: root,
      projectName: path.basename(root),
    );
    context.push(
      '/engine',
      extra: {
        'projectPath': root,
        'projectName': path.basename(root),
        'mode': 'offline',
      },
    );
  }

  Future<void> _createCloudProject(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Войдите в аккаунт для облачного проекта'),
        ),
      );
      return;
    }
    final name = TextEditingController();
    var visibility = 'private';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Облачный проект'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Хранение на сервере, привязка к аккаунту.'),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Доступ',
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'private',
                    label: Text('Приватно'),
                    icon: Icon(Icons.lock_outline, size: 18),
                  ),
                  ButtonSegment(
                    value: 'link',
                    label: Text('По slug'),
                    icon: Icon(Icons.link, size: 18),
                  ),
                ],
                selected: {visibility},
                onSelectionChanged: (s) => setS(() => visibility = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final prov = context.read<ProjectProvider>();
    final err = await prov.createProject(name.text.trim(), null, visibility);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Облачный проект создан')));
    }
  }

  Future<void> _joinBySlug(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сначала войдите')));
      return;
    }
    final slug = _slugCtrl.text.trim();
    if (slug.isEmpty) return;
    final prov = context.read<ProjectProvider>();
    final preview = await prov.previewShareSlug(slug);
    if (!context.mounted) return;
    if (preview == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ссылка недействительна')));
      return;
    }
    final owner = preview['owner_nickname']?.toString() ?? '?';
    final pname = preview['name']?.toString() ?? 'Проект';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(pname),
        content: Text('Автор: @$owner\nДобавить проект в список?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Вступить'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final err = await prov.joinProjectBySlug(slug);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Проект добавлен (просмотр)')),
      );
      _slugCtrl.clear();
    }
  }

  Widget _eyebrow(String text, ColorScheme cs) {
    return Text(
      text.toUpperCase(),
      style: NexusTheme.standaloneTextStyle(
        GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: cs.primary.withValues(alpha: 0.85),
        ),
        fallbackFontSize: 10,
      ),
    );
  }

  Widget _actionCard({
    required BuildContext context,
    required NexusShellTheme shell,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: shell.sidebarBorder.withValues(alpha: 0.65),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: iconColor ?? cs.primary),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPanel(BuildContext context, {required bool isAuth}) {
    final cs = Theme.of(context).colorScheme;
    final shell = context.nexusShell;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: shell.sidebarBorder.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Информация',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Формат проекта: v1.0.0',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            isAuth
                ? 'Играть на телефоне: облачные проекты. Редактирование доступно владельцу/редактору.'
                : 'Войдите в аккаунт для облачных проектов и совместной работы.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectTile(BuildContext context, Project p) {
    final cs = Theme.of(context).colorScheme;
    final shell = context.nexusShell;
    final role = p.isViewerOnly ? 'READ-ONLY' : 'OWNER';
    final slugPart = p.shareSlug != null ? ' · ${p.shareSlug}' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            context.read<ProjectProvider>().setCurrentProject(p);
            context.push('/project/${p.id}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: shell.sidebarBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  p.isViewerOnly
                      ? Icons.visibility_outlined
                      : Icons.cloud_outlined,
                  color: p.isViewerOnly ? cs.tertiary : cs.secondary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$role · ${p.visibility}$slugPart',
                        style: NexusTheme.standaloneTextStyle(
                          GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                          fallbackFontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context, AuthProvider auth, ColorScheme cs, NexusShellTheme shell) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.20),
            cs.secondary.withValues(alpha: 0.12),
            cs.surfaceContainerHighest.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: shell.sidebarBorder.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.apps_rounded, size: 32, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рабочая область',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Создавайте проекты на диске или в облаке, открывайте папку с project.json, импортируйте архив. '
                      'Нативное Rust-ядро нужно для редактора и Play.',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        height: 1.45,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 16),
            Material(
              color: cs.surface.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await context.push('/engine-install');
                  await _loadEngineStatus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.memory_rounded,
                        color: _engineStatusLine?.contains('Установлено') == true
                            ? cs.primary
                            : cs.error,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Нативное ядро',
                              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
                            ),
                            Text(
                              _engineStatusLine ?? 'Проверка…',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _localProjectTile(BuildContext context, _LocalProjectEntry p) {
    final cs = Theme.of(context).colorScheme;
    final shell = context.nexusShell;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            context.push(
              '/engine',
              extra: {
                'projectPath': p.path,
                'projectName': p.name,
                'mode': 'offline',
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: shell.sidebarBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special_outlined,
                  color: cs.primary,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LOCAL · offline',
                        style: NexusTheme.standaloneTextStyle(
                          GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            height: 1.3,
                          ),
                          fallbackFontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final projects = context.watch<ProjectProvider>().projects;
    final cs = Theme.of(context).colorScheme;
    final shell = context.nexusShell;

    return ColoredBox(
      color: shell.contentChrome,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
            sliver: SliverToBoxAdapter(child: _heroHeader(context, auth, cs, shell)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _eyebrow('Workspace', cs),
                const SizedBox(height: 6),
                Text(
                  'Новый проект',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                ),
                const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 560;
              final cardHeight = wide ? 180.0 : 150.0;
              final local = _actionCard(
                context: context,
                shell: shell,
                icon: Icons.folder_special_outlined,
                title: 'Локальный проект',
                iconColor: cs.primary,
                onTap: kIsWeb ? () {} : () => _createOfflineProject(context),
              );
              final cloud = _actionCard(
                context: context,
                shell: shell,
                icon: Icons.cloud_queue_outlined,
                title: 'Облачный проект',
                iconColor: auth.isAuthenticated
                    ? cs.secondary
                    : cs.onSurfaceVariant,
                onTap: () => _createCloudProject(context),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(height: cardHeight, child: local),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(height: cardHeight, child: cloud),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: cardHeight, child: local),
                  const SizedBox(height: 12),
                  SizedBox(height: cardHeight, child: cloud),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _infoPanel(context, isAuth: auth.isAuthenticated),
          if (!kIsWeb) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openProjectFolder(context),
                    icon: const Icon(Icons.folder_open_outlined, size: 20),
                    label: const Text('Открыть папку проекта'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _importProjectZip(context),
                    icon: const Icon(Icons.archive_outlined, size: 20),
                    label: const Text('Импорт ZIP'),
                  ),
                ),
              ],
            ),
            if (_localProjects.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Локальные проекты',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Обновить список локальных проектов',
                    onPressed: () => _loadLocalProjects(force: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._localProjects
                  .map(
                    (p) => _localProjectTile(context, p),
                  )
                  .toList(),
            ],
          ],
          if (auth.isAuthenticated) ...[
            const SizedBox(height: 28),
            _eyebrow('Collaboration', cs),
            const SizedBox(height: 10),
            Text(
              'Вступить по slug',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: shell.sidebarBorder.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _slugCtrl,
                      style: NexusTheme.standaloneTextStyle(
                        GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          color: cs.onSurface,
                        ),
                        fallbackFontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'share_slug',
                        hintStyle: NexusTheme.standaloneTextStyle(
                          GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                          ),
                          fallbackFontSize: 13,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () => _joinBySlug(context),
                    child: const Text('Вступить'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Облачные проекты',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Обновить список',
                  onPressed: () async {
                    final err = await context
                        .read<ProjectProvider>()
                        .loadProjects();
                    if (context.mounted && err != null) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(err)));
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (projects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Пока нет облачных проектов — создайте или вступите по slug.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...projects.map((p) => _projectTile(context, p)            ),
          ] else ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.6),
                ),
                color: cs.surfaceContainerHighest.withValues(alpha: 0.15),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Войдите, чтобы создавать облачные проекты, вступать по slug и видеть список на сервере.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalProjectEntry {
  final String path;
  final String name;
  final DateTime updatedAt;

  const _LocalProjectEntry({
    required this.path,
    required this.name,
    required this.updatedAt,
  });
}
