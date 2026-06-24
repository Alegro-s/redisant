import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../app/providers/settings_provider.dart';
import '../../arcade/arcade_publish_service.dart';
import '../../../app/widgets/lynx_external_links.dart';
import '../../../app/widgets/lynx_logo.dart';
import '../project_git.dart';
import '../project_manager.dart';
import '../providers/engine_workspace_provider.dart';
import '../providers/scene_provider.dart';
import '../widgets/engine_shell_tab_bar.dart';
import '../runtime/engine_binary_loader.dart';
import '../widgets/engine_bottom_dock.dart';
import '../widgets/unified_asset_workspace.dart';
import '../widgets/tic_console_map_editor.dart';
import '../runtime/tic_grid_codec.dart';
import '../runtime/nexus_play_snapshot.dart';
import '../runtime/project_build.dart';
import '../widgets/nexus_editor_theme.dart';
import '../widgets/project_explorer_panel.dart';
import '../widgets/engine_plugins_dialog.dart';
import '../widgets/engine_project_settings_dialog.dart';
import '../widgets/lynx_plugin_chips_bar.dart';
import '../widgets/lynx_export_sheet.dart';
import '../widgets/lynx_scene_plugins_panel.dart';
import '../../plugins/lynx_plugin_host.dart';
import '../../plugins/lynx_plugin_manifest.dart';
import '../widgets/scene_hierarchy_panel.dart';
import '../widgets/scene_minimap_panel.dart';
import '../widgets/scene_rooms_editor_dialog.dart';
import '../widgets/scene_editor.dart';
import '../widgets/engine_scene_viewport_controller.dart';
import '../runtime/lynx_blueprint_service.dart';
import '../widgets/engine_editor_shortcuts_dialog.dart';
import '../widgets/scene_object_inspector.dart';
import '../../cloud/lynx_cloud_sync.dart';
import '../widgets/scene_physics_panel.dart';
import '../../plugins/lynx_3d/lynx3d_core_viewport.dart';
import '../../plugins/lynx_3d/lynx_3d_codec.dart';
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

const double _kEngineCompactLayoutMaxSide = 600;

class _EngineMainPageState extends State<EngineMainPage> {
  String? _selectedAssetId;
  bool _bootStarted = false;
  bool _loading = false;
  String? _loadError;

  int _mobileWorkspaceTab = 1;

  bool _dockExpanded = true;
  int _dockTab = EngineBottomDock.kTabConsole;
  int _engineShellTab = 0;
  final EngineWorkspaceProvider _workspace = EngineWorkspaceProvider();
  final List<String> _consoleLines = [];
  String? _engineDockLabel;

  static const int _kMaxConsoleLines = 500;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final EngineSceneViewportController _sceneViewportController =
      EngineSceneViewportController();
  double _editorViewScale = 1.0;
  double _rightPanelWidth = 300;
  double _assetSidebarWidth = 220;
  double _explorerHeightFraction = 0.33;

  Widget _hResizeHandle({required void Function(double delta) onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: const SizedBox(width: 5),
      ),
    );
  }

  Widget _vResizeHandle({required void Function(double delta) onDrag}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        child: const SizedBox(height: 5),
      ),
    );
  }

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
    _sceneViewportController.dispose();
    _workspace.dispose();
    super.dispose();
  }

  void _onEngineShellTab(int tab, ProjectManager manager) {
    setState(() => _engineShellTab = tab);
    _workspace.setMainTabIndex(tab);
    if (tab == 2) {
      setState(() => _mobileWorkspaceTab = 2);
    } else if (tab == 0) {
      setState(() => _mobileWorkspaceTab = 1);
    } else if (tab == 3) {
      setState(() => _mobileWorkspaceTab = 2);
    }
  }

  bool _isTicProject(ProjectManager manager) {
    final mode = manager.projectSettings?.projectMode ?? LynxProjectMode.d2;
    final tpl = manager.projectSettings?.gameTemplate ?? '';
    return mode == LynxProjectMode.tic ||
        projectUsesTicApi(gameTemplate: tpl, projectMode: mode.jsonValue);
  }

  Future<void> _publishCartToCloud(ProjectManager manager) async {
    final root = widget.projectPath ?? manager.rootPath;
    if (root == null) return;
    await publishProjectCartToArcade(
      context,
      projectRoot: root,
      project: manager.projectSettings,
    );
  }

  bool _focusInEditableText() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null;
  }

  bool _keyModPressed(Set<LogicalKeyboardKey> keys) =>
      keys.contains(LogicalKeyboardKey.controlLeft) ||
      keys.contains(LogicalKeyboardKey.controlRight) ||
      keys.contains(LogicalKeyboardKey.metaLeft) ||
      keys.contains(LogicalKeyboardKey.metaRight);

  bool _keyShiftPressed(Set<LogicalKeyboardKey> keys) =>
      keys.contains(LogicalKeyboardKey.shiftLeft) ||
      keys.contains(LogicalKeyboardKey.shiftRight);

  bool _isZoomInKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.equal ||
      k == LogicalKeyboardKey.numpadAdd ||
      k == LogicalKeyboardKey.add;

  bool _isZoomOutKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract;

  bool _isZeroKey(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0;

  void _setUiScale(double next) {
    setState(() => _editorViewScale = next.clamp(0.72, 1.65));
  }

  void _nudgeUiScale(double delta) {
    _setUiScale(_editorViewScale + delta);
  }

  bool _handleEditorHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (_focusInEditableText()) return false;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final mod = _keyModPressed(keys);
    final shift = _keyShiftPressed(keys);
    final k = event.logicalKey;

    if (k == LogicalKeyboardKey.f1 ||
        (mod && k == LogicalKeyboardKey.slash)) {
      if (!mounted) return false;
      showEngineEditorShortcutsDialog(context);
      return true;
    }

    if (k == LogicalKeyboardKey.f5) {
      if (!mounted) return false;
      setState(() => _engineShellTab = 1);
      return true;
    }

    if (!mod) {
      if (k == LogicalKeyboardKey.delete ||
          k == LogicalKeyboardKey.backspace) {
        if (!mounted) return false;
        final sp = Provider.of<SceneProvider>(context, listen: false);
        final mgr = Provider.of<ProjectManager>(context, listen: false);
        final id = sp.selectedObjectId;
        if (id != null) {
          sp.pushUndoSnapshot();
          sp.removeObject(id);
          mgr.scheduleSceneSave();
          return true;
        }
        return false;
      }
      if (k == LogicalKeyboardKey.escape) {
        if (!mounted) return false;
        Provider.of<SceneProvider>(context, listen: false).selectObject(null);
        setState(() {});
        return true;
      }
      if (k == LogicalKeyboardKey.keyT) {
        if (!mounted) return false;
        final sp = Provider.of<SceneProvider>(context, listen: false);
        final scene = sp.currentScene;
        if (scene != null && scene.tilemaps.isNotEmpty) {
          sp.setTileEditMode(!sp.tileEditMode);
          return true;
        }
        return false;
      }
      return false;
    }

    if (k == LogicalKeyboardKey.keyS && !shift) {
      if (!mounted) return false;
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      unawaited(mgr.saveCurrentSceneManually());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сцена сохранена'), duration: Duration(seconds: 1)),
      );
      return true;
    }

    if (k == LogicalKeyboardKey.keyS && shift) {
      if (!mounted) return false;
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      final sp = Provider.of<SceneProvider>(context, listen: false);
      unawaited(_workspaceAction(context, mgr, sp, 'script'));
      return true;
    }

    if (k == LogicalKeyboardKey.keyI && shift) {
      if (!mounted) return false;
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      final sp = Provider.of<SceneProvider>(context, listen: false);
      unawaited(_workspaceAction(context, mgr, sp, 'sprite'));
      return true;
    }

    if (k == LogicalKeyboardKey.digit1 || k == LogicalKeyboardKey.numpad1) {
      setState(() => _engineShellTab = 0);
      return true;
    }
    if (k == LogicalKeyboardKey.digit2 || k == LogicalKeyboardKey.numpad2) {
      setState(() => _engineShellTab = 1);
      return true;
    }
    if (k == LogicalKeyboardKey.digit3 || k == LogicalKeyboardKey.numpad3) {
      setState(() => _engineShellTab = 2);
      return true;
    }

    if (_isZoomInKey(k)) {
      if (shift) {
        _nudgeUiScale(0.08);
      } else if (_engineShellTab == 0) {
        _sceneViewportController.zoomIn();
      } else {
        _nudgeUiScale(0.08);
      }
      return true;
    }
    if (_isZoomOutKey(k)) {
      if (shift) {
        _nudgeUiScale(-0.08);
      } else if (_engineShellTab == 0) {
        _sceneViewportController.zoomOut();
      } else {
        _nudgeUiScale(-0.08);
      }
      return true;
    }
    if (_isZeroKey(k)) {
      if (shift) {
        _setUiScale(1.0);
      } else if (_engineShellTab == 0) {
        _sceneViewportController.resetView();
      } else {
        _setUiScale(1.0);
      }
      return true;
    }

    if (k == LogicalKeyboardKey.keyD) {
      if (!mounted) return false;
      final sp = Provider.of<SceneProvider>(context, listen: false);
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      final id = sp.selectedObjectId;
      final scene = sp.currentScene;
      if (id == null || scene == null) return false;
      SceneObject? src;
      for (final o in scene.objects) {
        if (o.id == id) {
          src = o;
          break;
        }
      }
      if (src == null || src.locked) return false;
      sp.pushUndoSnapshot();
      final copy = src.copyWith(
        id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
        x: src.x + sp.objectSnapStep,
        y: src.y + sp.objectSnapStep,
      );
      sp.addObject(copy);
      sp.selectObject(copy.id);
      mgr.scheduleSceneSave();
      return true;
    }

    if (k == LogicalKeyboardKey.keyB && shift) {
      if (!mounted) return false;
      final mgr = Provider.of<ProjectManager>(context, listen: false);
      ProjectAsset? asset;
      if (_selectedAssetId != null) {
        for (final a in mgr.assets) {
          if (a.id == _selectedAssetId && a.type == 'script') {
            asset = a;
            break;
          }
        }
      }
      if (asset == null) return false;
      unawaited(openBlueprintEditorForScript(context, mgr, asset));
      return true;
    }

    if (k == LogicalKeyboardKey.keyZ) {
      if (!mounted) return false;
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
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final err = await manager.loadCloudProject(
      widget.projectId!,
      auth.http,
      displayName: widget.projectName ?? 'Облако',
      readOnly: widget.cloudReadOnly,
      corporateLocalOnly: settings.corporateLocalOnly,
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
    final pp = manager.projectSettings?.pixelPerfect ?? false;
    final ppu = manager.projectSettings?.pixelsPerUnit ?? 1.0;
    sceneProvider.setObjectSnapStep(pp ? (1.0 / ppu).clamp(1.0, 64.0) : 1.0);
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

  bool _isCompactEngineLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < _kEngineCompactLayoutMaxSide;

  bool _isCompactLandscape(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.shortestSide < _kEngineCompactLayoutMaxSide && size.width > size.height;
  }

  bool _explorerNodeVisible(ProjectNode node) {
    if (node.type == 'scene') return true;
    return node.type == 'sprite' ||
        node.type == 'script' ||
        node.type == 'sound';
  }

  void _onProjectNodeSelected(
    BuildContext context,
    ProjectNode node,
    ProjectManager manager,
    SceneProvider sceneProvider,
  ) {
    final narrow = _isCompactEngineLayout(context);
    if (node.type == 'sprite') {
      sceneProvider.selectObject(null);
      setState(() {
        _selectedAssetId = node.id;
        _engineShellTab = 3;
        if (narrow) _mobileWorkspaceTab = 2;
      });
    } else if (node.type == 'script') {
      sceneProvider.selectObject(null);
      setState(() {
        _selectedAssetId = node.id;
        _engineShellTab = 2;
        if (narrow) _mobileWorkspaceTab = 2;
      });
    } else if (node.type == 'sound') {
      sceneProvider.selectObject(null);
      setState(() {
        _selectedAssetId = node.id;
        _engineShellTab = 3;
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
        _engineShellTab = 0;
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
        _engineShellTab = 0;
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
        final useMobileWorkspace = _isCompactEngineLayout(context);
        final compactLandscape = _isCompactLandscape(context);
        final showWebCloudHint = kIsWeb &&
            widget.projectId == null &&
            widget.projectPath == null &&
            manager.rootPath == null;

        return ChangeNotifierProvider.value(
          value: _workspace,
          child: NexusEditorTheme.scope(
          context,
          child: Stack(
            children: [
              if (showWebCloudHint)
                Positioned(
                  top: 56,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: cs.primaryContainer.withValues(alpha: 0.92),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Облачный проект не выбран. Откройте его из Lynx Cloud '
                              '(ссылка с ?project=cloud:<id>) — данные хранятся на сервере.',
                              style: TextStyle(color: cs.onPrimaryContainer, height: 1.35),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final uri = Uri.parse(
                                'https://lynx-cloud.ru/cabinet/projects',
                              );
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                            child: const Text('Lynx Cloud'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(
                    LynxPluginHost.instance.editorStatusChips().isNotEmpty ? 88 : 44,
                  ),
                  child: Column(
                    children: [
                      EngineShellTabBar(
                        index: _engineShellTab,
                        onChanged: (i) => _onEngineShellTab(i, manager),
                      ),
                      if (LynxPluginHost.instance.editorStatusChips().isNotEmpty)
                        const LynxPluginChipsBar(),
                    ],
                  ),
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
                    tooltip: 'Горячие клавиши (Ctrl+/)',
                    icon: const Icon(Icons.keyboard_outlined),
                    onPressed: () => showEngineEditorShortcutsDialog(context),
                  ),
                  IconButton(
                    tooltip: 'Документация Lynx',
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: () => openLynxDocs(context),
                  ),
                  if (useMobileWorkspace)
                    IconButton(
                      tooltip: 'Инструменты и масштаб',
                      icon: const Icon(Icons.tune_rounded),
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                    ),
                  if (syncWarn != null)
                    IconButton(
                      tooltip: syncWarn,
                      icon: Icon(Icons.cloud_sync, color: Colors.orange.shade300),
                      onPressed: () async {
                        final action = await showLynxCloudConflictDialog(
                          context,
                          message: syncWarn,
                          readOnly: readOnly,
                        );
                        if (action != null && context.mounted) {
                          await handleLynxCloudConflictAction(context, manager, action);
                        }
                      },
                    ),
                  if (widget.projectId != null)
                    IconButton(
                      tooltip: 'Открыть в браузере',
                      icon: const Icon(Icons.open_in_browser_outlined),
                      onPressed: () => openCloudProjectInBrowser(
                        context,
                        projectId: widget.projectId!,
                        projectName: widget.projectName,
                        readOnly: readOnly,
                      ),
                    ),
                  if (!readOnly && manager.rootPath != null && !kIsWeb)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => showLynxExportSheet(
                          context,
                          projectRoot: manager.rootPath!,
                        ),
                        icon: const Icon(Icons.build_circle_outlined, size: 18),
                        label: const Text('Сборка'),
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
                          value: 'sound',
                          child: Text('Импорт звука'),
                        ),
                        const PopupMenuItem(
                          value: 'new_scene',
                          child: Text('Новая сцена (холст)'),
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
                          value: 'plugins',
                          child: Text('Плагины Lynx…'),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Text('Экспорт сцены (JSON)…'),
                        ),
                        if (!kIsWeb) ...[
                          const PopupMenuItem(
                            value: 'export_game',
                            child: Text('Экспорт игры (Player)…'),
                          ),
                          const PopupMenuItem(
                            value: 'export_build',
                            child: Text('Сборка game_data (быстро)…'),
                          ),
                          if (context.read<AuthProvider>().isAuthenticated)
                            const PopupMenuItem(
                              value: 'publish_arcade',
                              child: Text('Выложить cart в Аркаду…'),
                            ),
                        ],
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
                              ListTile(
                                leading: const Icon(Icons.extension_outlined),
                                title: const Text('Плагины Lynx'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _workspaceAction(
                                    context,
                                    manager,
                                    sceneProvider,
                                    'plugins',
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : null,
              body: Column(
                children: [
                  Expanded(
                    child: useMobileWorkspace
                        ? (compactLandscape
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildAssetSidebarColumn(
                                    context,
                                    cs: cs,
                                    panelBorder: panelBorder,
                                    manager: manager,
                                    sceneProvider: sceneProvider,
                                    showExitButton: false,
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          flex: 3,
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
                                          flex: 2,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: panelBg,
                                              border: Border(
                                                top: BorderSide(color: panelBorder),
                                              ),
                                            ),
                                            child: _buildExplorerWithFilters(
                                              context,
                                              readOnly: readOnly,
                                              manager: manager,
                                              sceneProvider: sceneProvider,
                                              showModeChips: false,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 260,
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
                              )
                            : IndexedStack(
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
                                child: _buildExplorerWithFilters(
                                  context,
                                  readOnly: readOnly,
                                  manager: manager,
                                  sceneProvider: sceneProvider,
                                  showModeChips: false,
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
                          ))
                        : Row(
                      children: [
                        _buildAssetSidebarColumn(
                          context,
                          cs: cs,
                          panelBorder: panelBorder,
                          manager: manager,
                          sceneProvider: sceneProvider,
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: ((1 - _explorerHeightFraction) * 100).round().clamp(40, 80),
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
                                    _vResizeHandle(
                                      onDrag: (dy) => setState(() {
                                        _explorerHeightFraction = (_explorerHeightFraction + dy / 400).clamp(0.18, 0.55);
                                      }),
                                    ),
                                    Expanded(
                                      flex: (_explorerHeightFraction * 100).round().clamp(20, 60),
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
                                          nodeVisible: _explorerNodeVisible,
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
                              _hResizeHandle(
                                onDrag: (dx) => setState(() {
                                  _rightPanelWidth = (_rightPanelWidth - dx).clamp(220.0, 560.0);
                                }),
                              ),
                              Container(
                                width: _rightPanelWidth,
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
              bottomNavigationBar: useMobileWorkspace && !compactLandscape
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
            if (syncWarn != null)
              Positioned(
                top: kToolbarHeight + 8,
                left: 12,
                right: 12,
                child: LynxCloudSyncBanner(
                  message: syncWarn,
                  readOnly: readOnly,
                  onResolve: () async {
                    final action = await showLynxCloudConflictDialog(
                      context,
                      message: syncWarn,
                      readOnly: readOnly,
                    );
                    if (action != null && context.mounted) {
                      await handleLynxCloudConflictAction(context, manager, action);
                    }
                  },
                ),
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
      setState(() {
        _selectedAssetId = asset.id;
        _engineShellTab = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.cloudAssetIdForProjectAssetId(asset.id) != null
                ? '${asset.name} — вкладка «Ассеты», копия в облаке'
                : '${asset.name} — вкладка «Ассеты»',
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
    } else if (action == 'plugins') {
      if (manager.isCloudReadOnly) return;
      final ps = manager.projectSettings;
      if (ps == null || !context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => EnginePluginsDialog(manager: manager),
      );
      if (context.mounted) setState(() {});
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
      setState(() {
        _selectedAssetId = asset.id;
        _engineShellTab = 2;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            manager.cloudAssetIdForProjectAssetId(asset.id) != null
                ? '${asset.name} — вкладка «Код», копия в облаке'
                : '${asset.name} — вкладка «Код»',
          ),
        ),
      );
    } else if (action == 'sound') {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['wav', 'mp3', 'ogg', 'm4a'],
      );
      if (pick == null || pick.files.single.path == null || !context.mounted) return;
      final asset = await manager.importSoundFromFile(pick.files.single.path!);
      if (!context.mounted) return;
      if (asset == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось импортировать звук')),
        );
        return;
      }
      setState(() {
        _selectedAssetId = asset.id;
        _engineShellTab = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asset.name} — вкладка «Ассеты»')),
      );
    } else if (action == 'new_scene') {
      final ctrl = TextEditingController(text: 'level_${manager.scenes.length + 1}');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Новая сцена'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Имя сцены'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
          ],
        ),
      );
      final name = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true || name.isEmpty || !context.mounted) return;
      final scene = await manager.createScene(name);
      sceneProvider.setCurrentScene(scene);
      setState(() => _engineShellTab = 0);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сцена «$name» — отдельный холст')),
        );
      }
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
    } else if (action == 'export_game') {
      final root = manager.rootPath;
      if (root != null) {
        await showLynxExportSheet(context, projectRoot: root);
      }
    } else if (action == 'export_build') {
      await _exportDesktopBuild(context, manager);
    } else if (action == 'publish_arcade') {
      await _publishCartToCloud(manager);
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

  Widget _buildMainTabContent(
    BuildContext context,
    ProjectManager manager, {
    required bool readOnly,
    required bool canPlay,
    required String? playPath,
  }) {
    switch (_engineShellTab) {
      case 1:
        return _buildGameViewTab(
          context,
          canPlay: canPlay,
          playPath: playPath,
          previewActive: true,
        );
      case 2:
        return _buildCodeWorkspaceTab(context, manager, readOnly: readOnly);
      case 3:
        return UnifiedAssetWorkspace(
          projectRoot: playPath,
          selectedAssetId: _selectedAssetId,
          readOnly: readOnly,
          onAssetSelected: (id) => setState(() => _selectedAssetId = id),
        );
      case 4:
        return _buildBuildTab(context, playPath);
      case 0:
      default:
        return _buildSceneTab(context, manager, playPath: playPath);
    }
  }

  Widget _buildSceneTab(
    BuildContext context,
    ProjectManager manager, {
    required String? playPath,
  }) {
    final sp = context.watch<SceneProvider>();
    final hasTic = playPath != null &&
        File(p.join(playPath, 'assets', 'tic', 'sprites.bank.json')).existsSync();
    final show3d = LynxPluginHost.instance.is3dActive &&
        sp.show3dViewportPreview &&
        playPath != null;

    Lynx3dSceneExtension? ext3d;
    if (show3d && sp.currentScene != null) {
      ext3d = Lynx3dSceneExtension.fromMap(
        sp.currentScene!.extensions['lynx.3d'] as Map<String, dynamic>?,
      );
      ext3d ??= const Lynx3dSceneExtension(
        active: true,
        gravity: [0, -9.81, 0],
        ambientColor: '#404050',
        camera: Lynx3dCameraSettings(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (show3d && ext3d != null)
          Expanded(
            flex: 2,
            child: Lynx3dCoreViewport(
              extension: ext3d,
              projectPath: playPath,
              simulatePhysics: false,
            ),
          ),
        Expanded(
          flex: show3d ? 3 : (hasTic ? 3 : 1),
          child: SceneEditor(viewportController: _sceneViewportController),
        ),
        if (hasTic) ...[
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: TicConsoleMapEditor(projectRoot: playPath),
          ),
        ],
      ],
    );
  }

  Widget _buildBuildTab(BuildContext context, String? playPath) {
    final cs = Theme.of(context).colorScheme;
    if (playPath == null) {
      return Center(
        child: Text(
          'Откройте проект с диска для сборки.',
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'Сборка и экспорт',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Экспорт .lynxcart, веб-сборка, Windows Player и публикация в аркаду.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => showLynxExportSheet(context, projectRoot: playPath),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Открыть панель сборки'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterWorkspace(
    BuildContext context,
    ProjectManager manager, {
    required bool readOnly,
    required bool canPlay,
    required String? playPath,
  }) {
    return _buildMainTabContent(
      context,
      manager,
      readOnly: readOnly,
      canPlay: canPlay,
      playPath: playPath,
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
      return ColoredBox(
        color: cs.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_esports_rounded, size: 72, color: cs.primary),
                const SizedBox(height: 20),
                Text(
                  'Игра',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Play открывается в отдельном окне — как в Unity.\n'
                  'Enter / тап — старт в logic-grid играх.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => context.push(
                    '/play',
                    extra: {'projectPath': playPath, 'freshPlay': false},
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text('Играть в отдельном окне'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => context.push(
                    '/play',
                    extra: {'projectPath': playPath, 'freshPlay': true},
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('С начала'),
                ),
              ],
            ),
          ),
        ),
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
    final tic = _isTicProject(manager);
    if (_selectedAssetId == null) {
      final scripts = manager.assets.where((a) => a.type == 'script').toList();
      if (scripts.isNotEmpty) {
        String? pickId;
        if (tic) {
          for (final hint in const ['game']) {
            final hit = scripts
                .where((a) => a.name.toLowerCase().contains(hint))
                .firstOrNull;
            if (hit != null) {
              pickId = hit.id;
              break;
            }
          }
        }
        pickId ??= scripts.first.id;
        return ScriptEditor(assetId: pickId);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            readOnly
                ? 'Облако (только чтение): выберите скрипт в проводнике.'
                : tic
                    ? 'Создайте assets/scripts/game.lua — TIC API: spr(), map(), btn().'
                    : 'Выберите .lua в проводнике или меню ⋮ → новый скрипт.',
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

  Widget _buildAssetSidebarColumn(
    BuildContext context, {
    required ColorScheme cs,
    required Color panelBorder,
    required ProjectManager manager,
    required SceneProvider sceneProvider,
    double width = 56,
    bool showExitButton = true,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        border: Border(right: BorderSide(color: panelBorder)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const LynxLogo(size: 28, compact: true),
          const Spacer(),
          if (showExitButton)
            IconButton(
              tooltip: 'Выход',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              icon: const Icon(Icons.exit_to_app_outlined, size: 20),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExplorerWithFilters(
    BuildContext context, {
    required bool readOnly,
    required ProjectManager manager,
    required SceneProvider sceneProvider,
    bool showModeChips = false,
  }) {
    return ProjectExplorerPanel(
      readOnly: readOnly,
      minimalPngBytes: kNexusMinimalPng,
      nodeVisible: _explorerNodeVisible,
      onNodeSelected: (node) => _onProjectNodeSelected(
        context,
        node,
        manager,
        sceneProvider,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
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
        SizedBox(
          height: 132,
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
            child: ListenableBuilder(
              listenable: _sceneViewportController,
              builder: (context, _) => SceneMinimapPanel(
                viewportMatrix: _sceneViewportController.viewportMatrix,
                viewportSize: _sceneViewportController.viewportSize,
                onFocusScenePoint: _sceneViewportController.focusScenePoint,
              ),
            ),
          ),
        ),
        Expanded(
          child: sel != null
              ? SceneObjectInspector(key: ValueKey(sel.id), object: sel)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (LynxPluginHost.instance.is3dActive)
                      const Expanded(
                        flex: 2,
                        child: LynxScenePluginsPanel(),
                      ),
                    const Expanded(
                      flex: 3,
                      child: ScenePhysicsPanel(),
                    ),
                  ],
                ),
        ),
      ],
    );
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
                  ? 'Выберите объект на сцене.'
                  : 'Выберите объект на сцене — свойства появятся здесь.',
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
