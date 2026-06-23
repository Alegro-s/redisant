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
import '../../auth/providers/auth_provider.dart';
import '../../arcade/arcade_publish_service.dart';
import '../../../app/widgets/lynx_external_links.dart';
import '../../../app/widgets/lynx_logo.dart';
import '../project_git.dart';
import '../project_manager.dart';
import '../providers/engine_workspace_provider.dart';
import '../providers/scene_provider.dart';
import '../runtime/lynx_cart_io.dart';
import '../widgets/console_mode_shell.dart';
import '../widgets/engine_shell_tab_bar.dart';
import '../runtime/engine_binary_loader.dart';
import '../widgets/embedded_game_preview.dart';
import '../widgets/engine_bottom_dock.dart';
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
import '../../plugins/lynx_3d/lynx_3d_editor_viewport.dart';
import '../../plugins/lynx_plugin_manifest.dart';
import '../widgets/scene_hierarchy_panel.dart';
import '../widgets/scene_minimap_panel.dart';
import '../widgets/scene_rooms_editor_dialog.dart';
import '../widgets/sound_asset_panel.dart';
import '../widgets/scene_editor.dart';
import '../widgets/engine_scene_viewport_controller.dart';
import '../runtime/lynx_blueprint_service.dart';
import '../widgets/engine_editor_shortcuts_dialog.dart';
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

const double _kEngineCompactLayoutMaxSide = 600;

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
  int _engineShellTab = 1;
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
    switch (tab) {
      case 0:
        setState(() => _workspaceViewTab = 0);
        break;
      case 1:
        setState(() => _mobileWorkspaceTab = 1);
        break;
      case 2:
        setState(() {
          _assetsMode = _AssetsSidebarMode.coding;
          _mobileWorkspaceTab = 2;
        });
        break;
      case 3:
        setState(() {
          _assetsMode = _AssetsSidebarMode.all;
          _mobileWorkspaceTab = 0;
        });
        break;
      case 4:
        final root = widget.projectPath ?? manager.rootPath;
        if (root != null && _runtimeSupportedOnDevice) {
          context.push('/play', extra: {'projectPath': root, 'freshPlay': true});
        }
        break;
      case 5:
        final root = widget.projectPath ?? manager.rootPath;
        if (root != null) {
          unawaited(showLynxExportSheet(context, projectRoot: root));
        }
        break;
    }
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
      setState(() => _workspaceViewTab = 1);
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
      setState(() => _workspaceViewTab = 0);
      return true;
    }
    if (k == LogicalKeyboardKey.digit2 || k == LogicalKeyboardKey.numpad2) {
      setState(() => _workspaceViewTab = 1);
      return true;
    }
    if (k == LogicalKeyboardKey.digit3 || k == LogicalKeyboardKey.numpad3) {
      setState(() => _workspaceViewTab = 2);
      return true;
    }

    if (_isZoomInKey(k)) {
      if (shift) {
        _nudgeUiScale(0.08);
      } else if (_workspaceViewTab == 0) {
        _sceneViewportController.zoomIn();
      } else {
        _nudgeUiScale(0.08);
      }
      return true;
    }
    if (_isZoomOutKey(k)) {
      if (shift) {
        _nudgeUiScale(-0.08);
      } else if (_workspaceViewTab == 0) {
        _sceneViewportController.zoomOut();
      } else {
        _nudgeUiScale(-0.08);
      }
      return true;
    }
    if (_isZeroKey(k)) {
      if (shift) {
        _setUiScale(1.0);
      } else if (_workspaceViewTab == 0) {
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
        return false;
    }
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
    } else if (node.type == 'sound') {
      sceneProvider.selectObject(null);
      setState(() {
        _selectedAssetId = node.id;
        _workspaceViewTab = 0;
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
        final useMobileWorkspace = _isCompactEngineLayout(context);
        final compactLandscape = _isCompactLandscape(context);

        return ChangeNotifierProvider.value(
          value: _workspace,
          child: ListenableBuilder(
            listenable: _workspace,
            builder: (context, _) {
              if (_workspace.isConsole) {
                return ChangeNotifierProvider.value(
                  value: _workspace,
                  child: NexusEditorTheme.scope(
                  context,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(widget.projectName ?? 'Lynx Engine · Консоль'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => _workspace.setMode(EngineWorkspaceMode.project),
                      ),
                    ),
                    body: ConsoleModeShell(
                      projectRoot: playPath,
                      onExitConsole: () => _workspace.setMode(EngineWorkspaceMode.project),
                      viewportController: _sceneViewportController,
                      onConsoleLine: _appendConsoleLine,
                      previewActive: true,
                    ),
                  ),
                ),
                );
              }
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
                  IconButton(
                    tooltip: 'Режим Консоль (TIC)',
                    icon: Icon(_workspace.isConsole ? Icons.view_in_ar : Icons.sports_esports_outlined),
                    onPressed: () => _workspace.toggleMode(),
                  ),
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
                          if (manager.projectSettings?.cloudPublish?.enabled == true)
                            const PopupMenuItem(
                              value: 'publish_arcade',
                              child: Text('Выложить cart в Arcade…'),
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
                                              showModeChips: true,
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
                                  showModeChips: true,
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
        _assetsMode = _AssetsSidebarMode.sounds;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${asset.name} — предпросмотр справа')),
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
      setState(() => _workspaceViewTab = 0);
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

  Widget _buildCenterWorkspace(
    BuildContext context,
    ProjectManager manager, {
    required bool readOnly,
    required bool canPlay,
    required String? playPath,
  }) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.outline.withValues(alpha: 0.35);
    final sp = context.watch<SceneProvider>();
    final mode = manager.projectSettings?.projectMode ?? LynxProjectMode.d2;
    var show3d = LynxPluginHost.instance.is3dActive && mode != LynxProjectMode.d2;
    if (show3d) {
      final scene = sp.currentScene;
      final block = scene?.extensions[Lynx3dPluginIds.sceneExtensionKey];
      if (block is Map && block['active'] == false) show3d = false;
    }
    final tabs = show3d
        ? const ['Сцена', 'Игра', 'Код', '3D']
        : const ['Сцена', 'Игра', 'Код'];
    final tabCount = tabs.length;
    final tabIndex = _workspaceViewTab.clamp(0, tabCount - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: cs.surfaceContainerHigh.withValues(alpha: 0.55),
          child: SizedBox(
            height: 42,
            child: Row(
              children: List.generate(tabCount, (i) {
                final sel = tabIndex == i;
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
            index: tabIndex,
            children: [
              SceneEditor(viewportController: _sceneViewportController),
              _buildGameViewTab(
                context,
                canPlay: canPlay,
                playPath: playPath,
                previewActive: tabIndex == 1,
              ),
              _buildCodeWorkspaceTab(
                context,
                manager,
                readOnly: readOnly,
              ),
              if (show3d) const Lynx3dEditorViewport(),
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

  void _onSidebarModeSelected(
    BuildContext context,
    _AssetsSidebarMode mode,
    ProjectManager manager,
    SceneProvider sceneProvider,
  ) {
    setState(() {
      _assetsMode = mode;
      _selectedAssetId = null;
    });
    switch (mode) {
      case _AssetsSidebarMode.all:
        setState(() => _workspaceViewTab = 0);
        break;
      case _AssetsSidebarMode.sprites:
        setState(() => _workspaceViewTab = 0);
        final sprite = manager.assets.where((a) => a.type == 'sprite').firstOrNull;
        if (sprite != null) {
          setState(() => _selectedAssetId = sprite.id);
        } else {
          unawaited(_workspaceAction(context, manager, sceneProvider, 'sprite'));
        }
        break;
      case _AssetsSidebarMode.coding:
        setState(() => _workspaceViewTab = 2);
        final script = manager.assets.where((a) => a.type == 'script').firstOrNull;
        if (script != null) {
          setState(() => _selectedAssetId = script.id);
        } else {
          unawaited(_workspaceAction(context, manager, sceneProvider, 'script'));
        }
        break;
      case _AssetsSidebarMode.sounds:
        setState(() => _workspaceViewTab = 0);
        final sound = manager.assets.where((a) => a.type == 'sound').firstOrNull;
        if (sound != null) {
          setState(() => _selectedAssetId = sound.id);
        } else {
          unawaited(_workspaceAction(context, manager, sceneProvider, 'sound'));
        }
        break;
      case _AssetsSidebarMode.share:
        final root = manager.rootPath;
        if (root != null) {
          unawaited(showLynxExportSheet(context, projectRoot: root));
        }
        break;
    }
  }

  Widget _buildAssetSidebarColumn(
    BuildContext context, {
    required ColorScheme cs,
    required Color panelBorder,
    required ProjectManager manager,
    required SceneProvider sceneProvider,
    double width = 76,
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
          const SizedBox(height: 6),
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
          if (showExitButton) const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  _sidebarModeButton(
                    cs: cs,
                    panelBorder: panelBorder,
                    icon: Icons.dashboard_outlined,
                    label: 'Все',
                    selected: _assetsMode == _AssetsSidebarMode.all,
                    onTap: () => _onSidebarModeSelected(
                      context,
                      _AssetsSidebarMode.all,
                      manager,
                      sceneProvider,
                    ),
                  ),
                  _sidebarModeButton(
                    cs: cs,
                    panelBorder: panelBorder,
                    icon: Icons.image_outlined,
                    label: 'Спрайты',
                    selected: _assetsMode == _AssetsSidebarMode.sprites,
                    onTap: () => _onSidebarModeSelected(
                      context,
                      _AssetsSidebarMode.sprites,
                      manager,
                      sceneProvider,
                    ),
                  ),
                  _sidebarModeButton(
                    cs: cs,
                    panelBorder: panelBorder,
                    icon: Icons.code_outlined,
                    label: 'Кодинг',
                    selected: _assetsMode == _AssetsSidebarMode.coding,
                    onTap: () => _onSidebarModeSelected(
                      context,
                      _AssetsSidebarMode.coding,
                      manager,
                      sceneProvider,
                    ),
                  ),
                  _sidebarModeButton(
                    cs: cs,
                    panelBorder: panelBorder,
                    icon: Icons.music_note_outlined,
                    label: 'Звук',
                    selected: _assetsMode == _AssetsSidebarMode.sounds,
                    onTap: () => _onSidebarModeSelected(
                      context,
                      _AssetsSidebarMode.sounds,
                      manager,
                      sceneProvider,
                    ),
                  ),
                  _sidebarModeButton(
                    cs: cs,
                    panelBorder: panelBorder,
                    icon: Icons.share_outlined,
                    label: 'Share',
                    selected: _assetsMode == _AssetsSidebarMode.share,
                    onTap: () => _onSidebarModeSelected(
                      context,
                      _AssetsSidebarMode.share,
                      manager,
                      sceneProvider,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showModeChips) _buildAssetsModeChips(context),
        Expanded(
          child: ProjectExplorerPanel(
            readOnly: readOnly,
            minimalPngBytes: kNexusMinimalPng,
            nodeVisible: _explorerNodeVisible,
            onNodeSelected: (node) => _onProjectNodeSelected(
              context,
              node,
              manager,
              sceneProvider,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetsModeChips(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget chip(String label, _AssetsSidebarMode mode, IconData icon) {
      final selected = _assetsMode == mode;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text(label),
          avatar: Icon(icon, size: 16),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) {
            final manager = Provider.of<ProjectManager>(context, listen: false);
            final sp = Provider.of<SceneProvider>(context, listen: false);
            _onSidebarModeSelected(context, mode, manager, sp);
          },
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
        ),
      );
    }

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            chip('Все', _AssetsSidebarMode.all, Icons.dashboard_outlined),
            chip('Спрайты', _AssetsSidebarMode.sprites, Icons.image_outlined),
            chip('Код', _AssetsSidebarMode.coding, Icons.code_outlined),
            chip('Звук', _AssetsSidebarMode.sounds, Icons.music_note_outlined),
            chip('Share', _AssetsSidebarMode.share, Icons.share_outlined),
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: side,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 60,
            height: 58,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? cs.secondary : cs.onSurfaceVariant,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
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
              : (_selectedAssetId == null
                    ? (LynxPluginHost.instance.is3dActive
                          ? const LynxScenePluginsPanel()
                          : _EmptyAssetPanel(readOnly: readOnly))
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
    } else if (asset.type == 'sound') {
      return SoundAssetPanel(assetId: assetId);
    } else if (asset.type == 'script') {
      return ScriptEditor(assetId: assetId);
    } else if (asset.type == 'model') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.view_in_ar_outlined, size: 48),
              const SizedBox(height: 12),
              Text(asset.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                asset.path,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                manager.isAssetPathDisabled(asset.path)
                    ? 'Ассет отключён в project.json'
                    : '3D-модель. Назначьте mesh в инспекторе объекта сцены.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => manager.setAssetPathEnabled(
                  asset.path,
                  manager.isAssetPathDisabled(asset.path),
                ),
                child: Text(
                  manager.isAssetPathDisabled(asset.path) ? 'Включить' : 'Отключить',
                ),
              ),
            ],
          ),
        ),
      );
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
                  : 'Проводник: спрайт или звук — редактор справа.\n'
                      'Lua / LynxScript — вкладка «Код». Blueprint: Ctrl+Shift+B.\n'
                      'Меню ⋮: тайлмап, звук, новая сцена, экспорт.',
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
