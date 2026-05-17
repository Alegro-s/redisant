import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:client/features/auth/providers/auth_provider.dart';
import 'package:client/features/engine/ffi/engine_bridge.dart';
import 'package:client/features/engine/ffi/engine_types.dart';
import 'package:client/features/engine/runtime/engine_binary_loader.dart';
import 'package:client/features/engine/runtime/nexus_gamepad_feeder.dart';
import 'package:client/features/game/game_play_loader.dart';
import 'package:client/features/game/game_touch_controls.dart';
import 'package:client/features/engine/runtime/engine_frame_stats.dart';
import 'package:client/features/game/game_render_snapshot.dart';
import 'package:client/features/game/game_world_painter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

class EmbeddedGamePreview extends StatefulWidget {
  final String projectPath;
  final bool freshPlay;
  final bool active;
  final void Function(String line)? onConsoleLine;

  const EmbeddedGamePreview({
    super.key,
    required this.projectPath,
    this.freshPlay = false,
    required this.active,
    this.onConsoleLine,
  });

  @override
  State<EmbeddedGamePreview> createState() => _EmbeddedGamePreviewState();
}

class _EmbeddedGamePreviewState extends State<EmbeddedGamePreview>
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

  Map<String, dynamic> _playBootstrap = const {};
  List<Map<String, dynamic>> _tilesetCatalog = const [];
  double _cameraX = 640;
  double _cameraY = 360;
  double _zoom = 1;
  double _designW = 1280;
  double _designH = 720;

  final Map<String, ui.Image> _textureCache = {};
  Duration? _prevTick;
  double _elapsedSec = 0;

  final Set<LogicalKeyboardKey> _held = {};
  bool _camTouchLeft = false;
  bool _camTouchRight = false;
  bool _camTouchUp = false;
  bool _camTouchDown = false;
  bool _paused = false;
  bool _showFrameStats = false;
  final ValueNotifier<EngineFrameStats?> _frameStats = ValueNotifier(null);
  final AudioPlayer _audio = AudioPlayer();

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _bootstrap();
    }
  }

  @override
  void didUpdateWidget(covariant EmbeddedGamePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _bootstrap();
    } else if (!widget.active && oldWidget.active) {
      _teardownRuntime();
    }
    if (widget.active &&
        widget.projectPath != oldWidget.projectPath) {
      _teardownRuntime();
      _bootstrap();
    }
  }

  void _teardownRuntime() {
    _frameStats.value = null;
    _ticker?.dispose();
    _ticker = null;
    if (!sceneIsNull(_sceneHandle)) {
      EngineBridge.sceneDestroy(_sceneHandle);
      _sceneHandle = kSceneNull;
    }
    _engineReady = false;
    for (final im in _textureCache.values) {
      im.dispose();
    }
    _textureCache.clear();
    _renderSnapshot = GameRenderSnapshot.empty(
      designWidth: _designW,
      designHeight: _designH,
    );
    NexusGamepadFeeder.disposeForPlay();
  }

  Future<void> _bootstrap() async {
    if (!widget.active) return;
    if (kIsWeb) {
      if (mounted) setState(() => _error = 'В браузере встроенный предпросмотр с FFI недоступен. Используйте «Играть» при наличии wasm.');
      return;
    }
    final load = await loadPlayPayload(widget.projectPath, freshPlay: widget.freshPlay);
    if (!mounted) return;
    if (load.error != null) {
      setState(() => _error = load.error);
      return;
    }
    final rust = load.rustSceneJson;
    if (rust == null) {
      setState(() => _error = 'Нет данных сцены');
      return;
    }
    _playBootstrap = load.playBootstrap;
    _tilesetCatalog = List<Map<String, dynamic>>.from(
      (_playBootstrap['tilesets'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
    );
    _designW = (_playBootstrap['designWidth'] as num?)?.toDouble() ?? 1280;
    _designH = (_playBootstrap['designHeight'] as num?)?.toDouble() ?? 720;
    final cam = _playBootstrap['camera'] as Map<String, dynamic>?;
    _cameraX = (cam?['x'] as num?)?.toDouble() ?? _designW / 2;
    _cameraY = (cam?['y'] as num?)?.toDouble() ?? _designH / 2;
    _zoom = (cam?['zoom'] as num?)?.toDouble() ?? 1;
    _renderSnapshot = GameRenderSnapshot.empty(
      designWidth: _designW,
      designHeight: _designH,
      cameraX: _cameraX,
      cameraY: _cameraY,
      zoom: _zoom,
    );

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final cached = await ensureEngineBinary(auth.http);
      if (!mounted) return;
      EngineBridge.init(preferredLibraryPath: cached);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Движок: $e');
      return;
    }

    _engineReady = true;
    final newH = EngineBridge.sceneFromJson(rust);
    if (sceneIsNull(newH)) {
      setState(() => _error = 'Движок не смог разобрать сцену');
      return;
    }
    _sceneHandle = newH;
    NexusGamepadFeeder.attachForPlay();
    _refreshEntities();
    unawaited(_preloadTextures());
    _ticker?.dispose();
    _ticker = createTicker(_update)..start();
    if (mounted) setState(() {});
  }

  Future<void> _preloadTextures() async {
    final root = widget.projectPath;
    if (kIsWeb) return;
    final paths = <String>{};
    for (final e in _renderSnapshot.entities) {
      final sp = e['sprite'] as Map<String, dynamic>?;
      final tp = sp?['texture_path'] as String?;
      if (tp != null) paths.add(tp);
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
      if (rel != null && rel.isNotEmpty) paths.add(rel);
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
    if (_cameraManualInput()) return;
    final cc = sceneData['camera_center'] as Map<String, dynamic>?;
    if (cc != null) {
      _cameraX = (cc['x'] as num).toDouble();
      _cameraY = (cc['y'] as num).toDouble();
    }
    final cams = sceneData['cameras'] as List?;
    if (cams != null && cams.isNotEmpty) {
      final cam = cams.first as Map<String, dynamic>;
      final z = cam['zoom'];
      if (z is num) _zoom = z.toDouble();
    }
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
    if (!widget.active) return;
    final dt = _prevTick == null ? 0.0 : (elapsed - _prevTick!).inMicroseconds / 1e6;
    _prevTick = elapsed;
    _elapsedSec = elapsed.inMilliseconds / 1000.0;

    const pan = 520.0;
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

    var engineMs = 0.0;
    if (sceneIsNull(_sceneHandle)) return;
    if (!_paused) {
      final sw = Stopwatch()..start();
      EngineBridge.sceneUpdate(_sceneHandle, dt.clamp(0.0, 0.1));
      sw.stop();
      engineMs = sw.elapsedMicroseconds / 1000.0;
    }

    NexusGamepadFeeder.syncToScene(_sceneHandle);
    for (final s in EngineBridge.sceneDrainSounds(_sceneHandle)) {
      unawaited(_playProjectSound(s));
    }
    final logs = EngineBridge.sceneDrainDebugLog(_sceneHandle);
    if (logs.isNotEmpty && widget.onConsoleLine != null) {
      for (final line in logs) {
        widget.onConsoleLine!(line);
      }
    }

    _refreshEntities();
    _frameStats.value = EngineFrameStats(
      engineUpdateMs: engineMs,
      entityCount: _renderSnapshot.entities.length,
      tilemapLayerCount: _renderSnapshot.tilemaps.length,
    );
  }

  Future<void> _playProjectSound(String rel) async {
    final root = widget.projectPath;
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

  void _dispatchEngineKey(LogicalKeyboardKey key, bool down) {
    if (sceneIsNull(_sceneHandle)) return;
    if (key == LogicalKeyboardKey.space) {
      EngineBridge.sceneSetKey(_sceneHandle, ' ', down);
      return;
    }
    final ch = key.keyLabel;
    if (ch.length == 1) {
      EngineBridge.sceneSetKey(_sceneHandle, ch.toLowerCase(), down);
    }
  }

  @override
  void dispose() {
    _teardownRuntime();
    _frameStats.dispose();
    _focus.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!widget.active) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Предпросмотр приостановлен (вкладка «Игра» не активна).',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
        ),
      );
    }
    if (!_engineReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final showTouchHud = shortest < 640;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.videogame_asset_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Предпросмотр',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: cs.onSurface),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Пауза',
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 20),
                  onPressed: () => setState(() => _paused = !_paused),
                ),
                IconButton(
                  tooltip: 'Статистика кадра (движок)',
                  icon: Icon(
                    Icons.speed_outlined,
                    size: 20,
                    color: _showFrameStats ? cs.primary : null,
                  ),
                  onPressed: () => setState(() => _showFrameStats = !_showFrameStats),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/play', extra: {'projectPath': widget.projectPath}),
                  icon: const Icon(Icons.open_in_full, size: 18),
                  label: const Text('На весь экран'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final maxH = constraints.maxHeight;
              final fit =
                  math.min(maxW / _designW, maxH / _designH).clamp(0.05, 8.0).toDouble();
              final viewW = _designW * fit;
              final viewH = _designH * fit;
              final paintZoom = _zoom * fit;

              return ColoredBox(
                color: const Color(0xFF0d1117),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
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
                                setState(() => _paused = !_paused);
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
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: GameWorldPainter.fromSnapshot(
                                  snapshot: _renderSnapshot,
                                  paintZoom: paintZoom,
                                  elapsedSeconds: _elapsedSec,
                                  textureImages: _textureCache,
                                  tilesetCatalog: _tilesetCatalog,
                                  debugDrawRoomZones: false,
                                  debugDrawColliders: false,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showTouchHud && maxW >= 360)
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 40),
                                GameHoldButton(
                                  size: 40,
                                  icon: Icons.keyboard_arrow_up_rounded,
                                  onHold: () => setState(() => _camTouchUp = true),
                                  onRelease: () => setState(() => _camTouchUp = false),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GameHoldButton(
                                  size: 40,
                                  icon: Icons.keyboard_arrow_left_rounded,
                                  onHold: () => setState(() => _camTouchLeft = true),
                                  onRelease: () => setState(() => _camTouchLeft = false),
                                ),
                                const SizedBox(width: 40),
                                GameHoldButton(
                                  size: 40,
                                  icon: Icons.keyboard_arrow_right_rounded,
                                  onHold: () => setState(() => _camTouchRight = true),
                                  onRelease: () => setState(() => _camTouchRight = false),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 40),
                                GameHoldButton(
                                  size: 40,
                                  icon: Icons.keyboard_arrow_down_rounded,
                                  onHold: () => setState(() => _camTouchDown = true),
                                  onRelease: () => setState(() => _camTouchDown = false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (_paused)
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _paused = false),
                          child: Container(color: Colors.black38),
                        ),
                      ),
                    if (_showFrameStats)
                      Positioned(
                        right: 6,
                        top: 6,
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
                                      const Text('render Flutter/Skia'),
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
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
