import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../project_git.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';
import '../runtime/engine_binary_loader.dart';
import '../widgets/embedded_game_preview.dart';
import '../widgets/engine_bottom_dock.dart';
import '../runtime/nexus_play_snapshot.dart';
import '../runtime/project_build.dart';
import '../widgets/nexus_editor_theme.dart';
import '../widgets/project_explorer_panel.dart';
import '../widgets/engine_project_settings_dialog.dart';
import '../widgets/scene_hierarchy_panel.dart';
import '../widgets/scene_rooms_editor_dialog.dart';
import '../widgets/scene_editor.dart';
import '../widgets/scene_object_inspector.dart';
import 'sprite_editor.dart';
import 'script_editor.dart';
import '../models/engine_models.dart';

final Uint8List kNexusMinimalPng = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

class EngineMainPage extends StatefulWidget {
  final String? projectId;
  final String? projectName;
  final String? projectPath;

  final bool cloudReadOnly;
  const EngineMainPage({
    super.key,
    this.projectId,
    this.projectName,
    this.projectPath,
    this.cloudReadOnly = false,
  });

  @override
  State<EngineMainPage> createState() => _EngineMainPageState();
}

const double _kEngineWorkspaceWideMinWidth = 840;

enum _AssetsSidebarMode { all, sprites, coding, sounds, share }

class _EngineMainPageState extends State<EngineMainPage> {
  String? _selectedAssetId;
  bool _bootStarted = false;
  bool _loading = false;
  String? _loadError;

  int _mobileWorkspaceTab = 1;

  _AssetsSidebarMode _assetsMode = _AssetsSidebarMode.all;

  int _workspaceViewTab = 0;

  bool _dockExpanded = true;
  int _dockTab = EngineBottomDock.kTabConsole;
  final List<String> _consoleLines = [];
  String? _engineDockLabel;

  static const int _kMaxConsoleLines = 500;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double _editorViewScale = 1.0;

  bool get _runtimeSupportedOnDevice {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleEditorHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapLoad());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEngineVersionLabel());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleEditorHardwareKey);
    super.dispose();
  }

  bool _focusInEditableText() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  bool _handleEditorHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_focusInEditableText()) return false;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
    if (!ctrl) return false;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.equal ||
        k == LogicalKeyboardKey.numpadAdd ||
        k == LogicalKeyboardKey.add) {
      setState(() => _editorViewScale = (_editorViewScale + 0.08).clamp(0.72, 1.65));
      return true;
    }
    if (k == LogicalKeyboardKey.minus ||
        k == LogicalKeyboardKey.numpadSubtract) {
      setState(() => _editorViewScale = (_editorViewScale - 0.08).clamp(0.72, 1.65));
      return true;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      setState(() => _editorViewScale = 1.0);
      return true;
    }
    if (k == LogicalKeyboardKey.keyZ) {
      if (!mounted) return false;
      final shift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
          keys.contains(LogicalKeyboardKey.shiftRight);
      final sp = Provider.of<SceneProvider>(context, listen: false);
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      if (shift) {
        if (sp.redo((s) => mgr.replaceSceneById(s))) {
          mgr.scheduleSceneSave();
          return true;
        }
      } else {
        if (sp.undo((s) => mgr.replaceSceneById(s))) {
          mgr.scheduleSceneSave();
          return true;
        }
      }
      return false;
    }
    if (k == LogicalKeyboardKey.keyY) {
      if (!mounted) return false;
      final sp = Provider.of<SceneProvider>(context, listen: false);
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      if (sp.redo((s) => mgr.replaceSceneById(s))) {
        mgr.scheduleSceneSave();
        return true;
      }
      return false;
    }
    return false;
  }

  void _showEditorParityDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактор и Unity'),
        content: const SingleChildScrollView(
          child: Text(
            'Пока без полного паритета с Unity: нет построчных prefab-override по полям как в Inspector Unity — '
            'есть сводка отличий от шаблона и сброс узла к префабу. '
            'Тайл-кисть: одно действие отмены на мазок (не на каждый кадр перетаскивания кисти). '
            'Облачный Lua-редактор с подсветкой ближе к локальному ScriptEditor, но без live-коллаба Studio. '
            'Отмена сцены: Ctrl+Z, Ctrl+Shift+Z или Ctrl+Y, а также кнопки на панели.',
            style: TextStyle(height: 1.42),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadEngineVersionLabel() async {
    final v = await getInstalledEngineVersionLabel();
    if (mounted) setState(() => _engineDockLabel = v);
  }

  void _appendConsoleLine(String line) {
    if (!mounted) return;
    setState(() {
      _consoleLines.add(line);
      if (_consoleLines.length > _kMaxConsoleLines) {
        _consoleLines.removeRange(0, _consoleLines.length - _kMaxConsoleLines);
      }
    });
  }

  Future<void> _bootstrapLoad() async {
    if (_bootStarted || !mounted) return;
    _bootStarted = true;
    if (widget.projectPath != null) {
      await _loadLocalProject();
    } else if (widget.projectId != null) {
      await _loadCloudProject();
    }
  }

  Future<void> _loadLocalProject() async {
    final manager = Provider.of<ProjectManager>(context, listen: false);
    await manager.loadProject(widget.projectPath!);
    _afterProjectLoaded();
  }

  Future<void> _loadCloudProject() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Войдите в аккаунт, чтобы открыть облачный проект';
        });
      }
      return;
    }
    final manager = Provider.of<ProjectManager>(context, listen: false);
    final err = await manager.loadCloudProject(
      widget.projectId!,
      auth.http,
      displayName: widget.projectName ?? 'Облако',
      readOnly: widget.cloudReadOnly,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _loadError = err;
      });
      return;
    }
    setState(() => _loading = false);
    _afterProjectLoaded();
  }

  void _afterProjectLoaded() {
    final manager = Provider.of<ProjectManager>(context, listen: false);
    final sceneProvider = Provider.of<SceneProvider>(context, listen: false);
    if (manager.scenes.isEmpty) return;
    sceneProvider.setCurrentScene(manager.scenes.first);
    final cur = sceneProvider.currentScene;
    if (cur != null && cur.objects.isEmpty) {
      ProjectAsset? firstSprite;
      for (final a in manager.assets) {
        if (a.type == 'sprite') {
          firstSprite = a;
          break;
        }
      }
      final firstAnyAssetId = manager.assets.isNotEmpty ? manager.assets.first.id : 'test';
      final testObject = SceneObject(
        id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Object',
        assetId: firstSprite?.id ?? firstAnyAssetId,
        x: 200,
        y: 200,
        layerId: SceneLayer.defaultLayerId,
      );
      sceneProvider.addObject(testObject);
    }
  }

  @override
  void deactivate() {
    try {
      final m = context.read<ProjectManager>();
      m.disposeSceneCollaboration();
      m.disposeStudioCollaboration();
    } catch (_) {}
    super.deactivate();
  }

  void _onProjectNodeSelected(
    BuildContext context,
    ProjectNode node,
    ProjectManager manager,
    SceneProvider sceneProvider,
  ) {
    final narrow =
        MediaQuery.sizeOf(context).width < _kEngineWorkspaceWideMinWidth;
    if (node.type == 'sprite') {
      sceneProvider.selectObject(null);
      setState(() {
        _selectedAssetId = node.id;
        if (!narrow) _workspaceViewTab = 0;
        if (narrow) _mobileWorkspaceTab = 2;
      });
    } else if (node.type == 'script') {
      sceneProvider.selectObject(null);
      setState(() {
        _selectedAssetId = node.id;
        _workspaceViewTab = 2;
        if (narrow) _mobileWorkspaceTab = 2;
      });
    } else if (node.type == 'scene') {
      sceneProvider.selectObject(null);
      if (manager.scenes.isEmpty) return;
      final match = manager.scenes
          .where((s) => 'scene_${s.id}' == node.id)
          .toList();
      sceneProvider.setCurrentScene(
        match.isNotEmpty ? match.first : manager.scenes.first,
      );
      setState(() {
        _workspaceViewTab = 0;
        if (narrow) _mobileWorkspaceTab = 1;
      });
    } else if (node.type == 'prefab') {
      sceneProvider.selectObject(null);
      final rawId =
          node.id.startsWith('prefab_') ? node.id.substring(7) : node.id;
      PrefabDefinition? def;
      for (final p in manager.prefabs) {
        if (p.id == rawId) {
          def = p;
          break;
        }
      }
      if (def == null) return;
      manager.instantiatePrefabIntoCurrentScene(def);
      if (!context.mounted) return;
      setState(() {
        _workspaceViewTab = 0;
        if (narrow) _mobileWorkspaceTab = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Префаб «${def.name}» добавлен на сцену')),
      );
    }
  }

  void _trySceneCollaboration(
    BuildContext context,
    ProjectManager manager,
    SceneProvider sceneProvider,
  ) {
    if (widget.projectId == null ||
        widget.projectPath != null ||
        widget.cloudReadOnly) {
      manager.disposeSceneCollaboration();
      return;
    }
    final auth = context.read<AuthProvider>();
    final scene = sceneProvider.currentScene;
    if (!auth.isAuthenticated ||
        auth.token == null ||
        auth.user == null ||
        scene == null) {
      manager.disposeSceneCollaboration();
      return;
    }
    manager.ensureSceneCollaboration(
      projectId: widget.projectId!,
      sceneId: scene.id,
      token: auth.token!,
      userId: auth.user!.id,
      apiBaseUrl: auth.dioBaseUrl,
    );
  }

  void _tryStudioCollaboration(BuildContext context, ProjectManager manager) {
    if (widget.projectId == null || widget.cloudReadOnly) {
      manager.disposeStudioCollaboration();
      return;
    }
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.token == null || auth.user == null) {
      manager.disposeStudioCollaboration();
      return;
    }
    manager.ensureStudioCollaboration(
      projectId: widget.projectId!,
      token: auth.token!,
      userId: auth.user!.id,
      apiBaseUrl: auth.dioBaseUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Загрузка облачного проекта…'),
            ],
          ),
        ),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text('Ошибка'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _bootStarted = false;
                      _loadError = null;
                    });
                    _bootstrapLoad();
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer2<ProjectManager, SceneProvider>(
      builder: (context, manager, sceneProvider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          manager.setSceneProvider(sceneProvider);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _trySceneCollaboration(context, manager, sceneProvider);
          _tryStudioCollaboration(context, manager);
        });
        final readOnly = manager.isCloudReadOnly;
        final canPlay =
            (widget.projectPath != null || manager.rootPath != null) &&
            _runtimeSupportedOnDevice;
        final playPath = widget.projectPath ?? manager.rootPath;
        final syncWarn = manager.cloudSyncConflictMessage;

        final cs = Theme.of(context).colorScheme;
        final panelBg = cs.surfaceContainerHigh;
        final panelBorder = cs.outline.withValues(alpha: 0.35);
        final useMobileWorkspace =
            MediaQuery.sizeOf(context).width < _kEngineWorkspaceWideMinWidth;

        return NexusEditorTheme.scope(
          context,
          child: Stack(
            children: [
              Scaffold(
              key: _scaffoldKey,
              backgroundColor: cs.surface,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Назад / выйти из редактора',
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                title: Text(
                  widget.projectId != null && widget.projectPath == null
                      ? '${widget.projectName ?? "Editor"} · облако'
                      : (widget.projectName ?? 'Editor'),
                ),
                actions: [
                  if (!readOnly)
                    IconButton(
                      tooltip: 'Отменить (Ctrl+Z)',
                      icon: const Icon(Icons.undo_rounded),
                      onPressed: sceneProvider.canUndo
                          ? () {
                              if (sceneProvider
                                  .undo((s) => manager.replaceSceneById(s))) {
                                manager.scheduleSceneSave();
                              }
                            }
                          : null,
                    ),
                  if (!readOnly)
                    IconButton(
                      tooltip: 'Вернуть (Ctrl+Shift+Z)',
                      icon: const Icon(Icons.redo_rounded),
                      onPressed: sceneProvider.canRedo
                          ? () {
                              if (sceneProvider
                                  .redo((s) => manager.replaceSceneById(s))) {
                                manager.scheduleSceneSave();
                              }
                            }
                          : null,
                    ),
                  IconButton(
                    tooltip: 'Ограничения редактора',
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showEditorParityDialog(context),
                  ),
                  if (useMobileWorkspace)
                    IconButton(
                      tooltip: 'Инструменты и масштаб',
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                  if (syncWarn != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: Tooltip(
                          message: syncWarn,
                          child: Icon(
                            Icons.cloud_off,
                            color: Colors.orange.shade300,
                          ),
                        ),
                      ),
                    ),
                  if (!readOnly && manager.rootPath != null)
                    PopupMenuButton<String>(
                      tooltip: 'Сцена, спрайты, скрипты',
                      icon: const Icon(Icons.grid_view_rounded),
                      onSelected: (v) =>
                          _workspaceAction(context, manager, sceneProvider, v),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'sprite',
                          child: Text('Новый спрайт'),
                        ),
                        const PopupMenuItem(
                          value: 'script',
                          child: Text('Новый скрипт Lua'),
                        ),
                        const PopupMenuItem(
                          value: 'tilemap',
                          child: Text('Слой тайлмапа (чанк 32×32 → Rust)'),
                        ),
                        const PopupMenuItem(
                          value: 'rooms',
                          child: Text('Комнаты камеры (кламп)…'),
                        ),
                        const PopupMenuItem(
                          value: 'project_settings',
                          child: Text('Микшер + тайлсеты (project.json)…'),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Text('Экспорт сцены (JSON)…'),
                        ),
                        if (!kIsWeb)
                          const PopupMenuItem(
                            value: 'export_build',
                            child: Text('Сборка папки (данные + engine)…'),
                          ),
                      ],
                    ),
                  if (!readOnly && manager.rootPath != null && !kIsWeb)
                    PopupMenuButton<String>(
                      tooltip: 'Репозиторий Git',
                      icon: const Icon(Icons.history_edu_outlined),
                      onSelected: (v) async {
                        final root = manager.rootPath!;
                        if (v == 'git_init') {
                          final r = await projectGitInit(root);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                r.ok
                                    ? 'Git: ${r.output}'
                                    : 'Ошибка: ${r.output}',
                              ),
                            ),
                          );
                        } else if (v == 'git_commit') {
                          final msg = await _askCommitMessage(context);
                          if (msg == null || !context.mounted) return;
                          final r = await projectGitCommit(root, msg);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                r.ok ? 'Коммит выполнен' : r.output,
                              ),
                            ),
                          );
                        } else if (v == 'git_status') {
                          final r = await projectGitStatus(root);
                          if (!context.mounted) return;
                          await showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('git status'),
                              content: SingleChildScrollView(
                                child: Text(
                                  r.output.isEmpty ? '(пусто)' : r.output,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'git_init',
                          child: Text('Git: git init'),
                        ),
                        PopupMenuItem(
                          value: 'git_status',
                          child: Text('Git: status'),
                        ),
                        PopupMenuItem(
                          value: 'git_commit',
                          child: Text('Git: commit…'),
                        ),
                      ],
                    ),
                  if (canPlay && playPath != null)
                    PopupMenuButton<String>(
                      tooltip: 'Запуск (нужен engine.dll / .so)',
                      icon: const Icon(Icons.play_circle_outline),
                      onSelected: (v) async {
                        if (!context.mounted) return;
                        if (v == 'play') {
                          context.push(
                            '/play',
                            extra: {'projectPath': playPath},
                          );
                        } else if (v == 'fresh') {
                          context.push(
                            '/play',
                            extra: {'projectPath': playPath, 'freshPlay': true},
                          );
                        } else if (v == 'clear_snap') {
                          await NexusPlaySnapshot.clear(playPath);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Снимок play удалён'),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: 'play',
                          child: Text('Играть (или продолжить с сохранения)'),
                        ),
                        PopupMenuItem(
                          value: 'fresh',
                          child: Text('Играть с начала (игнорировать снимок)'),
                        ),
                        PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'clear_snap',
                          child: Text('Удалить снимок play'),
                        ),
                      ],
                    ),
                  if (!readOnly)
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () async {
                        await manager.saveCurrentSceneManually();
                        if (!context.mounted) return;
                        final err = manager.cloudSyncConflictMessage;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(err ?? 'Сцена сохранена'),
                            backgroundColor: err != null
                                ? Colors.deepOrange
                                : null,
                          ),
                        );
                      },
                    ),
                ],
              ),
              endDrawer: useMobileWorkspace
                  ? Drawer(
                      child: SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'Инструменты',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: Text(
                                'ПК: Ctrl+ / Ctrl− / Ctrl0 — масштаб интерфейса',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.save_outlined),
                              title: const Text('Сохранить сцену'),
                              enabled: !readOnly && manager.rootPath != null,
                              onTap: !readOnly && manager.rootPath != null
                                  ? () async {
                                      Navigator.pop(context);
                                      await manager.saveCurrentSceneManually();
                                      if (!context.mounted) return;
                                      final err = manager.cloudSyncConflictMessage;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(err ?? 'Сцена сохранена'),
                                          backgroundColor:
                                              err != null ? Colors.deepOrange : null,
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                            if (canPlay && playPath != null)
                              ListTile(
                                leading: const Icon(Icons.play_circle_outline),
                                title: const Text('Играть'),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/play', extra: {'projectPath': playPath});
                                },
                              ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.zoom_in_map_outlined),
                              title: const Text('Укрупнить'),
                              subtitle: const Text('Как Ctrl+'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() => _editorViewScale =
                                    (_editorViewScale + 0.1).clamp(0.72, 1.65));
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.zoom_out_map_outlined),
                              title: const Text('Уменьшить'),
                              subtitle: const Text('Как Ctrl−'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() => _editorViewScale =
                                    (_editorViewScale - 0.1).clamp(0.72, 1.65));
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.fit_screen_outlined),
                              title: const Text('Масштаб 100%'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() => _editorViewScale = 1.0);
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 16, bottom: 8),
                              child: Text(
                                'Текущий: ${(_editorViewScale * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            if (!readOnly && manager.rootPath != null) ...[
                              ListTile(
                                leading: const Icon(Icons.image_outlined),
                                title: const Text('Новый спрайт'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _workspaceAction(context, manager, sceneProvider, 'sprite');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.code_outlined),
                                title: const Text('Новый скрипт Lua'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _workspaceAction(context, manager, sceneProvider, 'script');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.grid_4x4_outlined),
                                title: const Text('Слой тайлмапа'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _workspaceAction(context, manager, sceneProvider, 'tilemap');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.crop_free_outlined),
                                title: const Text('Комнаты камеры'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _workspaceAction(context, manager, sceneProvider, 'rooms');
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.settings_outlined),
                                title: const Text('Настройки проекта'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _workspaceAction(
                                    context,
                                    manager,
                                    sceneProvider,
                                    'project_settings',
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : null,
              body: Transform.scale(
                scale: _editorViewScale,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                child: Column(
                children: [
                  Expanded(
                    child: useMobileWorkspace
                        ? IndexedStack(
                            index: _mobileWorkspaceTab,
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: panelBg,
                                  border: Border(
                                    bottom: BorderSide(color: panelBorder),
                                  ),
                                ),
                                child: ProjectExplorerPanel(
                                  readOnly: readOnly,
                                  minimalPngBytes: kNexusMinimalPng,
                                  onNodeSelected: (node) =>
                                      _onProjectNodeSelected(
                                        context,
                                        node,
                                        manager,
                                        sceneProvider,
                                      ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                color: cs.surface,
                                child: _buildCenterWorkspace(
                                  context,
                                  manager,
                                  readOnly: readOnly,
                                  canPlay: canPlay,
                                  playPath: playPath,
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: panelBg,
                                  border: Border(top: BorderSide(color: panelBorder)),
                                ),
                                child: _buildRightPanel(
                                  context,
                                  manager: manager,
                                  readOnly: readOnly,
                                  sceneProvider: sceneProvider,
                                ),
                              ),
                            ],
                          )
                        : Row(
                      children: [
                        Container(
                          width: 92,
                          decoration: BoxDecoration(
                            color: panelBg,
                            border: Border(
                              right: BorderSide(color: panelBorder),
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              Text(
                                'nexUs',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  fontSize: 16,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/');
                                  }
                                },
                                icon: const Icon(Icons.exit_to_app_outlined, size: 18),
                                label: const Text(
                                  'Выход',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              _sidebarModeButton(
                                cs: cs,
                                panelBorder: panelBorder,
                                icon: Icons.dashboard_outlined,
                                label: 'Все',
                                selected: _assetsMode == _AssetsSidebarMode.all,
                                onTap: () => setState(() {
                                  _assetsMode = _AssetsSidebarMode.all;
                                  _selectedAssetId = null;
                                }),
                              ),
                              _sidebarModeButton(
                                cs: cs,
                                panelBorder: panelBorder,
                                icon: Icons.image_outlined,
                                label: 'Спрайты',
                                selected: _assetsMode == _AssetsSidebarMode.sprites,
                                onTap: () => setState(() {
                                  _assetsMode = _AssetsSidebarMode.sprites;
                                  _selectedAssetId = null;
                                }),
                              ),
                              _sidebarModeButton(
                                cs: cs,
                                panelBorder: panelBorder,
                                icon: Icons.code_outlined,
                                label: 'Кодинг',
                                selected: _assetsMode == _AssetsSidebarMode.coding,
                                onTap: () => setState(() {
                                  _assetsMode = _AssetsSidebarMode.coding;
                                  _selectedAssetId = null;
                                }),
                              ),
                              _sidebarModeButton(
                                cs: cs,
                                panelBorder: panelBorder,
                                icon: Icons.music_note_outlined,
                                label: 'Звук',
                                selected: _assetsMode == _AssetsSidebarMode.sounds,
                                onTap: () => setState(() {
                                  _assetsMode = _AssetsSidebarMode.sounds;
                                  _selectedAssetId = null;
                                }),
                              ),
                              _sidebarModeButton(
                                cs: cs,
                                panelBorder: panelBorder,
                                icon: Icons.share_outlined,
                                label: 'Поделиться',
                                selected: _assetsMode == _AssetsSidebarMode.share,
                                onTap: () => setState(() {
                                  _assetsMode = _AssetsSidebarMode.share;
                                  _selectedAssetId = null;
                                }),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        color: cs.surface,
                                        child: _buildCenterWorkspace(
                                          context,
                                          manager,
                                          readOnly: readOnly,
                                          canPlay: canPlay,
                                          playPath: playPath,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        color: panelBg,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: panelBorder),
                                          ),
                                        ),
                                        child: ProjectExplorerPanel(
                                          readOnly: readOnly,
                                          minimalPngBytes: kNexusMinimalPng,
                                          nodeVisible: (node) {
                                            if (node.type == 'scene') {
                                              return true;
                                            }
                                            switch (_assetsMode) {
                                              case _AssetsSidebarMode.all:
                                                return node.type == 'sprite' ||
                                                    node.type == 'script' ||
                                                    node.type == 'sound';
                                              case _AssetsSidebarMode.sprites:
                                                return node.type == 'sprite';
                                              case _AssetsSidebarMode.coding:
                                                return node.type == 'script';
                                              case _AssetsSidebarMode.sounds:
                                                return node.type == 'sound';
                                              case _AssetsSidebarMode.share:
                                                return true;
                                            }
                                          },
                                          onNodeSelected: (node) =>
                                              _onProjectNodeSelected(
                                                context,
                                                node,
                                                manager,
                                                sceneProvider,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 300,
                                decoration: BoxDecoration(
                                  color: panelBg,
                                  border: Border(
                                    left: BorderSide(color: panelBorder),
                                  ),
                                ),
                                child: _buildRightPanel(
                                  context,
                                  manager: manager,
                                  readOnly: readOnly,
                                  sceneProvider: sceneProvider,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!kIsWeb)
                    EngineBottomDock(
                      expanded: _dockExpanded,
                      tabIndex: _dockTab,
                      onTabChanged: (i) => setState(() => _dockTab = i),
                      onToggleExpand: () => setState(() => _dockExpanded = !_dockExpanded),
                      consoleLines: _consoleLines,
                      onClearConsole: () => setState(() => _consoleLines.clear()),
                      engineVersionLabel: _engineDockLabel,
                    ),
                ],
              ),
              ),
              bottomNavigationBar: useMobileWorkspace
                  ? NavigationBar(
                      height: 72,
                      selectedIndex: _mobileWorkspaceTab,
                      onDestinationSelected: (i) =>
                          setState(() => _mobileWorkspaceTab = i),
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.folder_outlined),
                          selectedIcon: Icon(Icons.folder_rounded),
                          label: 'Проект',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.grid_on_outlined),
                          selectedIcon: Icon(Icons.grid_on_rounded),
                          label: 'Сцена',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.tune_outlined),
                          selectedIcon: Icon(Icons.tune_rounded),
                          label: 'Панель',
                        ),
                      ],
                    )
                  : null,
            ),
            if (manager.cloudAssetMutationBusy) ...[
              const ModalBarrier(dismissible: false, color: Color(0x66000000)),
              Center(
                child: Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 22,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Text(
                            manager.cloudAssetMutationMessage ??
                                'Связь с облаком…',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        );
      },
    );
  }

  Future<void> _workspaceAction(
    BuildContext context,
    ProjectManager manager,
    SceneProvider sceneProvider,
    String action,
  ) async {
    if (action == 'sprite') {
      final ctrl = TextEditingController(
        text: 'sprite_${DateTime.now().millisecondsSinceEpoch}',
      );
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Новый спрайт'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Имя (без .png)'),
            autofocus: true,
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
      final name = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true || !context.mounted) return;
      final asset = await manager.createSprite(name, kNexusMinimalPng);
      if (!context.mounted) return;
      if (asset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать спрайт')),
        );
        return;
      }
      if (manager.canPushCloudAsset) {
        await manager.ensureCloudIdForLocalAsset(asset.id);
      }
      if (!context.mounted) return;
      setState(() => _selectedAssetId = asset.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.cloudAssetIdForProjectAssetId(asset.id) != null
                ? '${asset.name} — редактор справа, копия в облаке'
                : '${asset.name} — пиксельный редактор справа',
          ),
        ),
      );
    } else if (action == 'tilemap') {
      sceneProvider.addDefaultTilemapLayer();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Слой тайлмапа: включите «Тайлы», кисть и слой на панели над сценой; сохранение — как обычно',
            ),
          ),
        );
      }
    } else if (action == 'rooms') {
      if (manager.isCloudReadOnly) return;
      await showSceneRoomsEditorDialog(
        context: context,
        sceneProvider: sceneProvider,
        manager: manager,
      );
    } else if (action == 'project_settings') {
      final ps = manager.projectSettings;
      if (ps == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => EngineProjectSettingsDialog(manager: manager),
      );
    } else if (action == 'script') {
      final ctrl = TextEditingController(
        text: 'script_${DateTime.now().millisecondsSinceEpoch}',
      );
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Новый скрипт'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Имя (без .lua)'),
            autofocus: true,
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
      final name = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true || !context.mounted) return;
      final asset = await manager.createScript(name, 'return\n');
      if (!context.mounted) return;
      if (asset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать скрипт')),
        );
        return;
      }
      if (manager.canPushCloudAsset) {
        await manager.ensureCloudIdForLocalAsset(asset.id);
      }
      if (!context.mounted) return;
      setState(() => _selectedAssetId = asset.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.cloudAssetIdForProjectAssetId(asset.id) != null
                ? '${asset.name} — редактор кода справа, копия в облаке'
                : '${asset.name} — редактор кода справа',
          ),
        ),
      );
    } else if (action == 'export') {
      final scene = sceneProvider.currentScene;
      if (scene == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Нет активной сцены')));
        return;
      }
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выбор папки недоступен в браузере')),
        );
        return;
      }
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || !context.mounted) return;
      final file = File(p.join(dir, '${scene.id}_export.json'));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(scene.toJson()),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(file.path)));
      }
    } else if (action == 'export_build') {
      await _exportDesktopBuild(context, manager);
    }
  }

  Future<void> _exportDesktopBuild(
    BuildContext context,
    ProjectManager manager,
  ) async {
    if (kIsWeb) return;
    final root = manager.rootPath;
    if (root == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final parent = await FilePicker.platform.getDirectoryPath();
    if (!mounted) return;
    if (parent == null) return;
    final outName =
        '${p.basename(root)}_export_${DateTime.now().millisecondsSinceEpoch}';
    final outDir = p.join(parent, outName);
    var lib = await getLastCachedEngineLibraryPath();
    lib ??= await ensureEngineBinary(auth.http);
    final err = await exportDesktopProjectBundle(
      projectRoot: root,
      outputDirectory: outDir,
      engineLibraryAbsolutePath: lib,
    );
    if (!mounted) return;
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
    } else {
      messenger.showSnackBar(SnackBar(content: Text('Готово: $outDir')));
    }
  }

  Widget _buildCenterWorkspace(
    BuildContext context,
    ProjectManager manager, {
    required bool readOnly,
    required bool canPlay,
    required String? playPath,
  }) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.outline.withValues(alpha: 0.35);
    const tabs = ['Сцена', 'Игра', 'Код'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
          child: SizedBox(
            height: 42,
            child: Row(
              children: List.generate(3, (i) {
                final sel = _workspaceViewTab == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _workspaceViewTab = i),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: sel ? cs.primary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[i],
                        style: TextStyle(
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                          color: sel ? cs.primary : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Divider(height: 1, color: border),
        Expanded(
          child: IndexedStack(
            index: _workspaceViewTab,
            children: [
              const SceneEditor(),
              _buildGameViewTab(
                context,
                canPlay: canPlay,
                playPath: playPath,
                previewActive: _workspaceViewTab == 1,
              ),
              _buildCodeWorkspaceTab(
                context,
                manager,
                readOnly: readOnly,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGameViewTab(
    BuildContext context, {
    required bool canPlay,
    required String? playPath,
    required bool previewActive,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (canPlay && playPath != null && !kIsWeb) {
      return EmbeddedGamePreview(
        projectPath: playPath,
        freshPlay: false,
        active: previewActive,
        onConsoleLine: _appendConsoleLine,
      );
    }
    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_esports_outlined,
                size: 56,
                color: cs.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                kIsWeb ? 'Предпросмотр (веб)' : 'Игра (предпросмотр)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                kIsWeb
                    ? 'В браузере нет FFI: откройте проект в десктоп-клиенте для живого предпросмотра.'
                    : 'Тот же запуск, что и из меню «плей»: сцена, Lua, ввод. '
                        'Во вкладке встроен рантайм; полный экран — кнопка в панели предпросмотра.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 22),
              if (canPlay && playPath != null)
                FilledButton.icon(
                  onPressed: () => context.push(
                    '/play',
                    extra: {'projectPath': playPath},
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Играть'),
                )
              else
                Text(
                  _runtimeSupportedOnDevice
                      ? 'Откройте проект с диска, чтобы появилась кнопка запуска.'
                      : 'На этой платформе предпросмотр движка пока недоступен.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, height: 1.4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeWorkspaceTab(
    BuildContext context,
    ProjectManager manager, {
    required bool readOnly,
  }) {
    final cs = Theme.of(context).colorScheme;
    if (_selectedAssetId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            readOnly
                ? 'Облако (только чтение): выберите скрипт в проводнике.'
                : 'Выберите .lua в проводнике или нажмите «+» → новый скрипт.\n'
                    'Редактирование — здесь, на вкладке «Код».',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
        ),
      );
    }
    ProjectAsset? asset;
    for (final a in manager.assets) {
      if (a.id == _selectedAssetId) {
        asset = a;
        break;
      }
    }
    if (asset == null || asset.type != 'script') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Вкладка «Код» показывает только Lua. Выберите скрипт в дереве.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
          ),
        ),
      );
    }
    return ScriptEditor(assetId: asset.id);
  }

  Widget _sidebarModeButton({
    required ColorScheme cs,
    required Color panelBorder,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bg = selected ? cs.primaryContainer.withValues(alpha: 0.18) : Colors.transparent;
    final side = selected
        ? BorderSide(color: cs.primary.withValues(alpha: 0.55), width: 1.0)
        : BorderSide(color: panelBorder.withValues(alpha: 0.0), width: 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: side,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? cs.secondary : cs.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? cs.onSurface : cs.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel(
    BuildContext context, {
    required ProjectManager manager,
    required bool readOnly,
    required SceneProvider sceneProvider,
  }) {
    final sel = sceneProvider.selectedObject;
    final scriptInCenter = _workspaceViewTab == 2 &&
        _selectedAssetId != null &&
        manager.assets.any(
          (a) => a.id == _selectedAssetId && a.type == 'script',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: const SceneHierarchyPanel(),
          ),
        ),
        Expanded(
          child: sel != null
              ? SceneObjectInspector(key: ValueKey(sel.id), object: sel)
              : (_selectedAssetId == null
                    ? _EmptyAssetPanel(readOnly: readOnly)
                    : (scriptInCenter
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  readOnly
                                      ? 'Скрипт открыт по центру (просмотр).'
                                      : 'Lua редактируется во вкладке «Код» в центре. '
                                          'Здесь остаются иерархия сцены и инспектор объекта.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            )
                          : _buildEditor(_selectedAssetId!))),
        ),
      ],
    );
  }

  Widget _buildEditor(String assetId) {
    final manager = Provider.of<ProjectManager>(context, listen: false);
    if (manager.isCloudReadOnly) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Режим просмотра: редактирование отключено'),
        ),
      );
    }
    final asset = manager.assets.firstWhere(
      (a) => a.id == assetId,
      orElse: () => ProjectAsset(
        id: '',
        name: '',
        type: '',
        path: '',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      ),
    );
    if (asset.type == 'sprite') {
      return SpriteEditor(assetId: assetId);
    } else if (asset.type == 'script') {
      return ScriptEditor(assetId: assetId);
    } else {
      return Center(child: Text('Cannot edit ${asset.type}'));
    }
  }
}

class _EmptyAssetPanel extends StatelessWidget {
  final bool readOnly;

  const _EmptyAssetPanel({required this.readOnly});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              readOnly
                  ? 'Просмотр: выберите ассет в проводнике.'
                  : 'Проводник снизу (ПК) или вкладка «Проект» (телефон): спрайт или звук — редактор здесь справа.\n'
                      'Lua — во вкладке «Код» по центру. Меню ⋮ на AppBar: тайлмап, экспорт, настройки.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _askCommitMessage(BuildContext context) async {
  final ctrl = TextEditingController(text: 'Lynx editor');
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Сообщение коммита'),
      content: TextField(
        controller: ctrl,
        decoration: const InputDecoration(labelText: 'git commit -m'),
        autofocus: true,
        onSubmitted: (_) {
          final t = ctrl.text.trim();
          if (t.isNotEmpty) Navigator.pop(ctx, t);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final t = ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(ctx, t);
          },
          child: const Text('Коммит'),
        ),
      ],
    ),
  );
  return (r != null && r.isNotEmpty) ? r : null;
}
