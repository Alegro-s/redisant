import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:client/features/engine/runtime/tic_audio_engine.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:client/features/auth/providers/auth_provider.dart';
import 'package:client/features/engine/ffi/engine_bridge.dart';
import 'package:client/features/engine/runtime/play_engine_init.dart';
import 'package:client/features/engine/ffi/engine_types.dart';
import 'package:client/features/engine/runtime/engine_frame_stats.dart';
import 'package:client/features/engine/runtime/engine_binary_loader.dart';
import 'package:client/features/engine/runtime/nexus_gamepad_feeder.dart';
import 'package:client/features/engine/runtime/nexus_play_snapshot.dart';
import 'package:client/features/engine/runtime/tic_audio_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'game_play_loader.dart';
import 'game_render_snapshot.dart';
import 'play_camera_sync.dart';
import 'game_touch_controls.dart';
import 'logic_grid_play_helpers.dart';
import 'game_3d_play_overlay.dart';
import 'bt_debug_overlay.dart';
import 'bt_debug_panel.dart';
import 'game_ui_overlay.dart';
import 'game_world_painter.dart';
import '../engine/runtime/lynx_windows_3d_runtime.dart';
import '../engine/runtime/unified_play_viewport.dart';
import '../plugins/lynx_3d/lynx3d_core_viewport.dart';
import '../plugins/lynx_3d/lynx_3d_codec.dart';
import 'sprite_uv_resolve.dart';

class GamePlayerScreen extends StatefulWidget {
  final String? projectPath;
  final bool freshPlay;
  /// Lynx Player (`main_player.dart`): движок из `bin/`, без Hub API.
  final bool standalonePlayer;
  /// E20b — cart play всегда pixel-perfect letterbox.
  final bool forcePixelPerfect;
  const GamePlayerScreen({
    super.key,
    this.projectPath,
    this.freshPlay = false,
    this.standalonePlayer = false,
    this.forcePixelPerfect = false,
  });

  @override
  State<GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends State<GamePlayerScreen>
    with SingleTickerProviderStateMixin {
  SceneHandle _sceneHandle = kSceneNull;
  Ticker? _ticker;
  GameRenderSnapshot _renderSnapshot = GameRenderSnapshot.empty(
    designWidth: 1280,
    designHeight: 720,
  );
  String? _error;
  bool _engineReady = false;
  final FocusNode _focus = FocusNode();

  List<Map<String, dynamic>> _uiWidgets = const [];
  Lynx3dSceneExtension? _lynx3d;
  bool _lynx3dPhysics = true;
  bool _lynx3dCoreViewport = false;
  Map<String, dynamic> _playBootstrap = const {};
  List<Map<String, dynamic>> _tilesetCatalog = const [];
  double _cameraX = 640;
  double _cameraY = 360;
  double _zoom = 1;
  double _designW = 1280;
  double _designH = 720;
  bool _pixelPerfect = false;

  final Map<String, ui.Image> _textureCache = {};
  Duration? _prevTick;
  double _elapsedSec = 0;

  final Set<LogicalKeyboardKey> _held = {};
  bool _camTouchLeft = false;
  bool _camTouchRight = false;
  bool _camTouchUp = false;
  bool _camTouchDown = false;
  int _touchGpMask = 0;

  bool get _isLogicGridGame => snapshotIsLogicGridGame(_renderSnapshot);
  bool _paused = false;
  String _currentSceneId = 'main';
  bool _sceneSwitching = false;
  bool _showDebug = false;
  bool _showFrameStats = false;
  final ValueNotifier<EngineFrameStats?> _frameStats = ValueNotifier(null);
  final List<String> _debugLines = [];
  List<Map<String, dynamic>> _btDebugEntries = const [];

  final AudioPlayer _audio = AudioPlayer();
  late final TicAudioEngine _ticAudio = TicAudioEngine(_audio);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadPlayScene(sceneIdOverride: null);
  }

  Future<void> _loadPlayScene({String? sceneIdOverride}) async {
    final load = await loadPlayPayload(
      widget.projectPath,
      freshPlay: widget.freshPlay,
      sceneIdOverride: sceneIdOverride,
    );
    if (!mounted) return;
    if (load.error != null) {
      setState(() {
        _error = load.error;
        _sceneSwitching = false;
      });
      return;
    }
    await _ticAudio.loadProject(widget.projectPath);
    final rust = load.rustSceneJson;
    if (rust == null) {
      setState(() {
        _error = 'Нет данных сцены';
        _sceneSwitching = false;
      });
      return;
    }
    _currentSceneId = load.sceneId;
    _playBootstrap = load.playBootstrap;
    _uiWidgets = List<Map<String, dynamic>>.from(
      (_playBootstrap['uiWidgets'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
    _tilesetCatalog = List<Map<String, dynamic>>.from(
      (_playBootstrap['tilesets'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
    _designW = (_playBootstrap['designWidth'] as num?)?.toDouble() ?? 1280;
    _designH = (_playBootstrap['designHeight'] as num?)?.toDouble() ?? 720;
    _pixelPerfect = widget.forcePixelPerfect ||
        (_playBootstrap['pixelPerfect'] as bool? ?? false);
    final cam = _playBootstrap['camera'] as Map<String, dynamic>?;
    _cameraX = (cam?['x'] as num?)?.toDouble() ?? _designW / 2;
    _cameraY = (cam?['y'] as num?)?.toDouble() ?? _designH / 2;
    _zoom = (cam?['zoom'] as num?)?.toDouble() ?? 1;
    final l3raw = _playBootstrap['lynx3d'];
    _lynx3d = l3raw is Map<String, dynamic>
        ? Lynx3dSceneExtension.fromMap(l3raw)
        : null;
    final l3map = _playBootstrap['lynx3d'] as Map?;
    _lynx3dPhysics = l3map?['simulatePhysics'] as bool? ?? true;
    _lynx3dCoreViewport = !kIsWeb &&
        !Platform.isAndroid &&
        !Platform.isIOS &&
        Lynx3dCoreViewport.isPlatformSupported &&
        LynxWindows3dRuntimeJson.fromJson(l3map?['windows3dRuntime'] as String?) ==
            LynxWindows3dRuntime.coreForwardD3d12;
    _renderSnapshot = GameRenderSnapshot.empty(
      designWidth: _designW,
      designHeight: _designH,
      cameraX: _cameraX,
      cameraY: _cameraY,
      zoom: _zoom,
    );

    if (!_engineReady) {
      if (!kIsWeb) {
        try {
          final lib = await resolvePlayEngineLibrary(
            http: widget.standalonePlayer ? null : _tryAuthHttp(context),
          );
          if (!mounted) return;
          if (lib == null || lib.isEmpty) {
            setState(() {
              _error = widget.standalonePlayer
                  ? 'Не найден движок. Положите engine.dll в папку bin/ рядом с Player.'
                  : 'Движок не установлен. Установите ядро в Hub или экспортируйте bin/.';
              _sceneSwitching = false;
            });
            return;
          }
          EngineBridge.init(preferredLibraryPath: lib);
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _error = 'Движок: $e';
            _sceneSwitching = false;
          });
          return;
        }
      } else {
        EngineBridge.init();
      }
      _engineReady = true;
    }

    if (!sceneIsNull(_sceneHandle)) {
      EngineBridge.sceneDestroy(_sceneHandle);
      _sceneHandle = kSceneNull;
    }
    final newH = EngineBridge.sceneFromJson(rust);
    if (sceneIsNull(newH)) {
      setState(() {
        _error = 'Движок не смог разобрать сцену';
        _sceneSwitching = false;
      });
      return;
    }
    _sceneHandle = newH;
    EngineBridge.sceneSetTicAudio(_sceneHandle, _ticAudio);
    if (load.useCartRuntime && load.cartLuaScript != null && load.cartLuaScript!.isNotEmpty) {
      EngineBridge.sceneInitCartLua(_sceneHandle, load.cartLuaScript!);
      if (kIsWeb) {
        EngineBridge.sceneSetTicAudio(_sceneHandle, _ticAudio);
      }
    }
    EngineBridge.sceneSetPaused(_sceneHandle, _paused);
    NexusGamepadFeeder.attachForPlay();
    _refreshEntities();
    unawaited(_preloadTextures());
    _ticker ??= createTicker(_update)..start();
    if (mounted) {
      setState(() {
        _error = null;
        _sceneSwitching = false;
      });
    }
  }

  Future<void> _preloadTextures() async {
    final root = widget.projectPath;
    if (root == null || kIsWeb) return;
    final paths = <String>{};
    for (final e in _renderSnapshot.entities) {
      final sp = e['sprite'] as Map<String, dynamic>?;
      final tp = sp?['texture_path'] as String?;
      if (tp != null) paths.add(normalizeTextureCacheKey(tp));
    }
    final wantedTilesets = <String>{};
    for (final l in _renderSnapshot.tilemaps) {
      final id = l['tileset_id'] as String?;
      if (id != null && id.isNotEmpty) wantedTilesets.add(id);
    }
    for (final t in _tilesetCatalog) {
      final tid = t['id'] as String?;
      if (tid == null || !wantedTilesets.contains(tid)) continue;
      final rel = t['texturePath'] as String? ?? t['texture_path'] as String?;
      if (rel != null && rel.isNotEmpty) {
        paths.add(normalizeTextureCacheKey(rel));
      }
    }
    for (final rel in paths) {
      if (_textureCache.containsKey(rel)) continue;
      try {
        final f = File(p.join(root, rel));
        if (!await f.exists()) continue;
        final bytes = await f.readAsBytes();
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        final frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() => _textureCache[rel] = frame.image);
      } catch (_) {}
    }
  }

  bool _cameraManualInput() =>
      _held.contains(LogicalKeyboardKey.arrowLeft) ||
      _held.contains(LogicalKeyboardKey.arrowRight) ||
      _held.contains(LogicalKeyboardKey.arrowUp) ||
      _held.contains(LogicalKeyboardKey.arrowDown) ||
      _camTouchLeft ||
      _camTouchRight ||
      _camTouchUp ||
      _camTouchDown;

  void _syncCameraFromEngine(Map<String, dynamic> sceneData) {
    if (sceneDataIsLogicGridGame(sceneData)) {
      lockCameraForLogicGrid(
        designWidth: _designW,
        designHeight: _designH,
        setCenter: (x, y) {
          _cameraX = x;
          _cameraY = y;
        },
        setZoom: (z) => _zoom = z,
      );
      return;
    }
    if (_cameraManualInput()) return;
    applyEngineCameraCenter(
      sceneData: sceneData,
      designWidth: _designW,
      designHeight: _designH,
      setCenter: (x, y) {
        _cameraX = x;
        _cameraY = y;
      },
      setZoom: (z) => _zoom = z,
    );
  }

  void _refreshEntities() {
    if (sceneIsNull(_sceneHandle)) return;
    final jsonStr = EngineBridge.sceneToJson(_sceneHandle);
    if (jsonStr != null) {
      final Map<String, dynamic> sceneData = jsonDecode(jsonStr);
      _syncCameraFromEngine(sceneData);
      final next = GameRenderSnapshot.fromEngineSceneMap(
        sceneData,
        cameraX: _cameraX,
        cameraY: _cameraY,
        zoom: _zoom,
        designWidth: _designW,
        designHeight: _designH,
      );
      if (mounted) {
        setState(() => _renderSnapshot = next);
        unawaited(_preloadTextures());
      }
    }
  }

  void _update(Duration elapsed) {
    final dt = _prevTick == null ? 0.0 : (elapsed - _prevTick!).inMicroseconds / 1e6;
    _prevTick = elapsed;
    _elapsedSec = elapsed.inMilliseconds / 1000.0;

    const pan = 520.0;
    if (!_isLogicGridGame) {
      if (_held.contains(LogicalKeyboardKey.arrowLeft) || _camTouchLeft) {
        _cameraX -= pan * dt;
      }
      if (_held.contains(LogicalKeyboardKey.arrowRight) || _camTouchRight) {
        _cameraX += pan * dt;
      }
      if (_held.contains(LogicalKeyboardKey.arrowUp) || _camTouchUp) {
        _cameraY -= pan * dt;
      }
      if (_held.contains(LogicalKeyboardKey.arrowDown) || _camTouchDown) {
        _cameraY += pan * dt;
      }
    }

    var engineMs = 0.0;
    if (sceneIsNull(_sceneHandle)) return;
    if (!_paused) {
      final sw = Stopwatch()..start();
      EngineBridge.sceneUpdate(_sceneHandle, dt.clamp(0.0, 0.1));
      sw.stop();
      engineMs = sw.elapsedMicroseconds / 1000.0;
    }

    if (!kIsWeb) {
      NexusGamepadFeeder.syncToScene(_sceneHandle);
    }
    for (final s in EngineBridge.sceneDrainSounds(_sceneHandle)) {
      unawaited(_dispatchEngineSound(s));
    }
    if (!kIsWeb) {
      final logs = EngineBridge.sceneDrainDebugLog(_sceneHandle);
      if (logs.isNotEmpty) {
        _debugLines.addAll(logs);
        while (_debugLines.length > 120) {
          _debugLines.removeAt(0);
        }
      }
      if (_showDebug) {
        final bt = EngineBridge.sceneDrainBtDebug(_sceneHandle);
        if (bt.length != _btDebugEntries.length ||
            bt.toString() != _btDebugEntries.toString()) {
          setState(() => _btDebugEntries = bt);
        }
      }
    }

    if (!_sceneSwitching && !sceneIsNull(_sceneHandle)) {
      final pending = EngineBridge.sceneTakePendingLoad(_sceneHandle);
      if (pending != null && pending.isNotEmpty && pending != _currentSceneId) {
        unawaited(_switchScene(pending));
        return;
      }
    }

    _refreshEntities();
    _frameStats.value = EngineFrameStats(
      engineUpdateMs: engineMs,
      entityCount: _renderSnapshot.entities.length,
      tilemapLayerCount: _renderSnapshot.tilemaps.length,
    );
  }

  void _handleUiAction(String action) {
    if (action.startsWith('load_scene:')) {
      final id = action.substring('load_scene:'.length).trim();
      if (id.isNotEmpty) unawaited(_switchScene(id));
    }
  }

  Dio? _tryAuthHttp(BuildContext context) {
    try {
      return Provider.of<AuthProvider>(context, listen: false).http;
    } catch (_) {
      return null;
    }
  }

  Future<void> _switchScene(String sceneId) async {
    if (_sceneSwitching || sceneId == _currentSceneId) return;
    _sceneSwitching = true;
    _releaseAllTouchEngineKeys();
    await _loadPlayScene(sceneIdOverride: sceneId);
  }

  void _setPaused(bool value) {
    if (_paused == value) return;
    _paused = value;
    if (!sceneIsNull(_sceneHandle)) {
      EngineBridge.sceneSetPaused(_sceneHandle, value);
    }
  }

  Future<void> _dispatchEngineSound(String rel) async {
    if (rel.trimLeft().startsWith('{')) {
      await _ticAudio.handleSoundEvent(rel);
      return;
    }
    await _playProjectSound(rel);
  }

  Future<void> _playProjectSound(String rel) async {
    final root = widget.projectPath;
    if (root == null || kIsWeb) return;
    var pathRel = rel;
    var vol = 0.85;
    if (rel.contains('|')) {
      final parts = rel.split('|');
      if (parts.length >= 3) {
        pathRel = parts[1];
        vol = double.tryParse(parts[2]) ?? vol;
      }
    }
    final norm = pathRel.replaceAll('/', Platform.pathSeparator);
    final path = p.isAbsolute(norm) ? norm : p.join(root, norm);
    try {
      await _audio.play(DeviceFileSource(path), volume: vol.clamp(0.0, 1.0));
    } catch (_) {}
  }

  void _engineCharKey(String ch, bool down) {
    if (sceneIsNull(_sceneHandle)) return;
    EngineBridge.sceneSetKey(_sceneHandle, ch, down);
  }

  void _onTouchArrow(LogicalKeyboardKey key, bool down) {
    if (_isLogicGridGame) {
      final bit = playGamepadBitForArrow(key);
      if (bit != 0) _touchGpBit(bit, down);
      return;
    }
    setState(() {
      switch (key) {
        case LogicalKeyboardKey.arrowLeft:
          _camTouchLeft = down;
        case LogicalKeyboardKey.arrowRight:
          _camTouchRight = down;
        case LogicalKeyboardKey.arrowUp:
          _camTouchUp = down;
        case LogicalKeyboardKey.arrowDown:
          _camTouchDown = down;
        default:
          break;
      }
    });
  }

  void _releaseAllTouchEngineKeys() {
    for (final c in ['a', 'd', 'w', ' ']) {
      _engineCharKey(c, false);
    }
    for (final k in [
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.enter,
    ]) {
      dispatchPlayEngineKey(_sceneHandle, k, false);
    }
    _touchGpMask = 0;
    setPlayGamepadButtons(_sceneHandle, 0);
  }

  void _touchGpBit(int bit, bool on) {
    if (on) {
      _touchGpMask |= bit;
    } else {
      _touchGpMask &= ~bit;
    }
    setPlayGamepadButtons(_sceneHandle, _touchGpMask);
  }

  void _dispatchEngineKey(LogicalKeyboardKey key, bool down) {
    dispatchPlayEngineKey(_sceneHandle, key, down);
  }

  @override
  void dispose() {
    NexusGamepadFeeder.disposeForPlay();
    _releaseAllTouchEngineKeys();
    _frameStats.dispose();
    _ticker?.dispose();
    if (!sceneIsNull(_sceneHandle)) EngineBridge.sceneDestroy(_sceneHandle);
    _focus.dispose();
    _audio.dispose();
    for (final im in _textureCache.values) {
      im.dispose();
    }
    super.dispose();
  }

  void _exitPlay(BuildContext context) {
    if (widget.standalonePlayer) {
      SystemNavigator.pop();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _savePlaySnapshot() async {
    final root = widget.projectPath;
    if (root == null || kIsWeb) return;
    if (sceneIsNull(_sceneHandle)) return;
    final jsonStr = EngineBridge.sceneToJson(_sceneHandle);
    if (jsonStr == null) return;
    try {
      await NexusPlaySnapshot.write(root, jsonStr);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Состояние play сохранено (.nexus/play_snapshot.json)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Игра'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _exitPlay(context),
          ),
        ),
        body: Center(child: Text(_error!, textAlign: TextAlign.center)),
      );
    }
    if (!_engineReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final showTouchHud = shortest < 640;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          kIsWeb
              ? 'Play · веб'
              : showTouchHud
                  ? 'Play 2D · сенсор / клавиатура · Esc — пауза'
                  : 'Play 2D · WASD · стрелки камера · Esc пауза',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _exitPlay(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Статистика кадра (движок)',
            icon: Icon(
              Icons.speed_outlined,
              color: _showFrameStats ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => setState(() => _showFrameStats = !_showFrameStats),
          ),
          IconButton(
            tooltip: 'Отладка: Lua, BT, collision, комнаты',
            icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () => setState(() => _showDebug = !_showDebug),
          ),
          if (widget.projectPath != null && !kIsWeb)
            IconButton(
              tooltip: 'Сохранить состояние',
              icon: const Icon(Icons.save_outlined),
              onPressed: _savePlaySnapshot,
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
            final fit = UnifiedPlayViewport.resolvePlayScale(
              maxWidth: maxW,
              maxHeight: maxH,
              designWidth: _designW,
              designHeight: _designH,
              pixelPerfect: _pixelPerfect,
            );
            final viewW = _designW * fit;
            final viewH = _designH * fit;
            final paintZoom = _zoom * fit;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xFF0d1117),
                    child: Center(
                      child: SizedBox(
                        width: viewW,
                        height: viewH,
                        child: Focus(
                          focusNode: _focus,
                          autofocus: true,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent) {
                              _held.add(event.logicalKey);
                              if (event.logicalKey == LogicalKeyboardKey.escape) {
                                setState(() => _setPaused(!_paused));
                                return KeyEventResult.handled;
                              }
                              _dispatchEngineKey(event.logicalKey, true);
                            } else if (event is KeyUpEvent) {
                              _held.remove(event.logicalKey);
                              _dispatchEngineKey(event.logicalKey, false);
                            }
                            return KeyEventResult.handled;
                          },
                          child: GestureDetector(
                            onTap: () => _focus.requestFocus(),
                            child: Stack(
                          children: [
                            RepaintBoundary(
                              child: CustomPaint(
                                painter: GameWorldPainter.fromSnapshot(
                                  snapshot: _renderSnapshot,
                                  paintZoom: paintZoom,
                                  elapsedSeconds: _elapsedSec,
                                  textureImages: _textureCache,
                                  tilesetCatalog: _tilesetCatalog,
                                  debugDrawRoomZones: _showDebug,
                                  debugDrawColliders: _showDebug,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            GameUiOverlay(
                              widgets: _uiWidgets,
                              viewWidth: viewW,
                              viewHeight: viewH,
                              cameraX: _cameraX,
                              cameraY: _cameraY,
                              paintZoom: paintZoom,
                              onAction: _handleUiAction,
                            ),
                            if (_lynx3d != null)
                              Positioned.fill(
                                child: _lynx3dCoreViewport
                                    ? Lynx3dCoreViewport(
                                        extension: _lynx3d!,
                                        projectPath: widget.projectPath,
                                        simulatePhysics:
                                            _lynx3dPhysics && !kIsWeb,
                                      )
                                    : Opacity(
                                        opacity: kIsWeb ? 0.35 : 0.88,
                                        child: Game3dPlayOverlay(
                                          extension: _lynx3d!,
                                          simulatePhysics:
                                              _lynx3dPhysics && !kIsWeb,
                                          projectPath: widget.projectPath,
                                        ),
                                      ),
                              ),
                          ],
                        ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showDebug && !kIsWeb) ...[
                  BtDebugOverlay(entries: _btDebugEntries),
                  Positioned(
                    right: 8,
                    top: 56,
                    child: BtDebugPanel(
                      scene: _sceneHandle,
                      onStep: () => setState(() => _paused = false),
                    ),
                  ),
                ],
                if (showTouchHud && maxW >= 400) ...[
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 48),
                            GameHoldButton(
                              size: 46,
                              icon: Icons.keyboard_arrow_up_rounded,
                              onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowUp, true),
                              onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowUp, false),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GameHoldButton(
                              size: 46,
                              icon: Icons.keyboard_arrow_left_rounded,
                              onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowLeft, true),
                              onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowLeft, false),
                            ),
                            const SizedBox(width: 46),
                            GameHoldButton(
                              size: 46,
                              icon: Icons.keyboard_arrow_right_rounded,
                              onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowRight, true),
                              onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowRight, false),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 48),
                            GameHoldButton(
                              size: 46,
                              icon: Icons.keyboard_arrow_down_rounded,
                              onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowDown, true),
                              onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowDown, false),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GameHoldButton(
                          size: 50,
                          icon: Icons.arrow_back_rounded,
                          onHold: () => _isLogicGridGame
                              ? _onTouchArrow(LogicalKeyboardKey.arrowLeft, true)
                              : _engineCharKey('a', true),
                          onRelease: () => _isLogicGridGame
                              ? _onTouchArrow(LogicalKeyboardKey.arrowLeft, false)
                              : _engineCharKey('a', false),
                        ),
                        const SizedBox(width: 10),
                        GameHoldButton(
                          size: 50,
                          icon: Icons.arrow_forward_rounded,
                          onHold: () => _isLogicGridGame
                              ? _onTouchArrow(LogicalKeyboardKey.arrowRight, true)
                              : _engineCharKey('d', true),
                          onRelease: () => _isLogicGridGame
                              ? _onTouchArrow(LogicalKeyboardKey.arrowRight, false)
                              : _engineCharKey('d', false),
                        ),
                        const SizedBox(width: 14),
                        GameHoldButton(
                          size: 56,
                          icon: Icons.rotate_right_rounded,
                          onHold: () => _isLogicGridGame
                              ? _touchGpBit(kPlayGpA, true)
                              : _engineCharKey(' ', true),
                          onRelease: () => _isLogicGridGame
                              ? _touchGpBit(kPlayGpA, false)
                              : _engineCharKey(' ', false),
                        ),
                        if (_isLogicGridGame) ...[
                          const SizedBox(width: 10),
                          GameHoldButton(
                            size: 50,
                            icon: Icons.vertical_align_bottom_rounded,
                            onHold: () => _touchGpBit(kPlayGpB, true),
                            onRelease: () => _touchGpBit(kPlayGpB, false),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (showTouchHud && maxW < 400)
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GameHoldButton(
                                size: 42,
                                icon: Icons.keyboard_arrow_left_rounded,
                                onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowLeft, true),
                                onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowLeft, false),
                              ),
                              GameHoldButton(
                                size: 42,
                                icon: Icons.keyboard_arrow_up_rounded,
                                onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowUp, true),
                                onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowUp, false),
                              ),
                              GameHoldButton(
                                size: 42,
                                icon: Icons.keyboard_arrow_down_rounded,
                                onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowDown, true),
                                onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowDown, false),
                              ),
                              GameHoldButton(
                                size: 42,
                                icon: Icons.keyboard_arrow_right_rounded,
                                onHold: () => _onTouchArrow(LogicalKeyboardKey.arrowRight, true),
                                onRelease: () => _onTouchArrow(LogicalKeyboardKey.arrowRight, false),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GameHoldButton(
                                size: 48,
                                icon: Icons.arrow_back_rounded,
                                onHold: () => _isLogicGridGame
                                    ? _onTouchArrow(LogicalKeyboardKey.arrowLeft, true)
                                    : _engineCharKey('a', true),
                                onRelease: () => _isLogicGridGame
                                    ? _onTouchArrow(LogicalKeyboardKey.arrowLeft, false)
                                    : _engineCharKey('a', false),
                              ),
                              const SizedBox(width: 8),
                              GameHoldButton(
                                size: 48,
                                icon: Icons.arrow_forward_rounded,
                                onHold: () => _isLogicGridGame
                                    ? _onTouchArrow(LogicalKeyboardKey.arrowRight, true)
                                    : _engineCharKey('d', true),
                                onRelease: () => _isLogicGridGame
                                    ? _onTouchArrow(LogicalKeyboardKey.arrowRight, false)
                                    : _engineCharKey('d', false),
                              ),
                              const SizedBox(width: 12),
                              GameHoldButton(
                                size: 48,
                                icon: Icons.rotate_right_rounded,
                                onHold: () => _isLogicGridGame
                                    ? _touchGpBit(kPlayGpA, true)
                                    : _engineCharKey(' ', true),
                                onRelease: () => _isLogicGridGame
                                    ? _touchGpBit(kPlayGpA, false)
                                    : _engineCharKey(' ', false),
                              ),
                              if (_isLogicGridGame) ...[
                                const SizedBox(width: 8),
                                GameHoldButton(
                                  size: 48,
                                  icon: Icons.vertical_align_bottom_rounded,
                                  onHold: () => _touchGpBit(kPlayGpB, true),
                                  onRelease: () => _touchGpBit(kPlayGpB, false),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_isLogicGridGame &&
                    logicGridPhase(_renderSnapshot) == 0 &&
                    !_paused)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => pulsePlayEngineKey(
                        _sceneHandle,
                        LogicalKeyboardKey.enter,
                      ),
                    ),
                  ),
                if (_paused)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _setPaused(false)),
                      child: Container(color: Colors.black45),
                    ),
                  ),
                if (_paused)
                  Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Пауза', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => setState(() => _setPaused(false)),
                              child: const Text('Продолжить'),
                            ),
                            TextButton(
                              onPressed: () => _exitPlay(context),
                              child: const Text('Выйти из play'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_showFrameStats)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: ValueListenableBuilder<EngineFrameStats?>(
                      valueListenable: _frameStats,
                      builder: (context, s, _) {
                        if (s == null) return const SizedBox.shrink();
                        return Material(
                          color: Colors.black.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: DefaultTextStyle(
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: Color(0xFFE6EDF3),
                                height: 1.35,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('logic_tick ${s.engineUpdateMs.toStringAsFixed(2)} ms'),
                                  Text('render Flutter/Skia'),
                                  Text('entities ${s.entityCount}'),
                                  Text('tilemaps ${s.tilemapLayerCount}'),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_showDebug)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    height: 160,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _debugLines.isEmpty ? '(лог Lua: nexus_log("...") в скрипте)' : _debugLines.join('\n'),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF7CFF9E),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
