import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../game/tilemap_layer_painter.dart';
import '../collab/collab_presence.dart';
import '../models/engine_models.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';
import '../runtime/collider_from_sprite_meta.dart';
import 'room_zones_paint.dart';
import 'scene_canvas_options_bar.dart';
import 'scene_scenes_tab_bar.dart';
import 'engine_scene_viewport_controller.dart';
import 'tilemap_editor_toolbar.dart';

const double kSceneEditorGridStep = 40;
const double kSceneCanvasWidth = 4096;
const double kSceneCanvasHeight = 4096;

double _snapToStep(double v, double step) =>
    (v / step).roundToDouble() * step;

SpriteAssetMeta? _metaForObject(SceneObject o, List<ProjectAsset> assets) {
  for (final a in assets) {
    if (a.id == o.assetId) return a.spriteMeta;
  }
  return null;
}

class SceneEditor extends StatefulWidget {
  const SceneEditor({super.key, this.viewportController});

  final EngineSceneViewportController? viewportController;

  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  String? _draggedObjectId;
  Offset? _dragOffset;
  bool _isDragging = false;
  bool _canvasPanning = false;
  Offset? _canvasPanAnchor;
  final TransformationController _viewportTransform = TransformationController();
  bool _tileStrokeUndoPushed = false;
  DateTime _lastPresenceSent = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, ui.Image> _editorTilesetImages = {};
  final Set<String> _editorTilesetLoading = {};

  Offset? _lastZoomFocal;
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.viewportController?.addListener(_applyViewportCommand);
    _viewportTransform.addListener(_onViewportTransformChanged);
  }

  void _onViewportTransformChanged() {
    widget.viewportController?.reportViewport(_viewportTransform.value, _viewportSize);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant SceneEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportController != widget.viewportController) {
      oldWidget.viewportController?.removeListener(_applyViewportCommand);
      widget.viewportController?.addListener(_applyViewportCommand);
    }
  }

  void _applyViewportCommand() {
    final ctrl = widget.viewportController;
    if (ctrl == null) return;
    final focus = ctrl.consumeFocusScenePoint();
    if (focus != null && _viewportSize.width > 1) {
      final m = Matrix4.identity()
        ..translate(
          _viewportSize.width * 0.5 - focus.dx,
          _viewportSize.height * 0.5 - focus.dy,
        );
      _viewportTransform.value = m;
      ctrl.reportViewport(m, _viewportSize);
      return;
    }
    if (ctrl.consumeReset()) {
      _viewportTransform.value = Matrix4.identity();
      return;
    }
    final factor = ctrl.consumeZoomFactor();
    if (factor == 1.0) return;
    final focal = _lastZoomFocal ??
        Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final m = Matrix4.copy(_viewportTransform.value);
    m.translate(focal.dx, focal.dy);
    m.scale(factor);
    m.translate(-focal.dx, -focal.dy);
    _viewportTransform.value = m;
  }

  @override
  void dispose() {
    widget.viewportController?.removeListener(_applyViewportCommand);
    _viewportTransform.dispose();
    for (final im in _editorTilesetImages.values) {
      im.dispose();
    }
    super.dispose();
  }

  Offset _scenePointFromViewport(Offset viewportLocal) {
    final matrix = Matrix4.inverted(_viewportTransform.value);
    return MatrixUtils.transformPoint(matrix, viewportLocal);
  }

  void _panCanvasBy(Offset delta) {
    final m = Matrix4.copy(_viewportTransform.value)..translate(delta.dx, delta.dy);
    _viewportTransform.value = m;
  }

  void _ensureEditorTilesetImages(Scene scene, ProjectManager manager) {
    if (kIsWeb) return;
    final root = manager.rootPath;
    if (root == null) return;
    final catalog = manager.projectSettings?.tilesets ?? const [];
    final wanted = <String>{};
    for (final l in scene.tilemaps) {
      final id = l.tilesetId;
      if (id != null && id.isNotEmpty) wanted.add(id);
    }
    for (final t in catalog) {
      if (!wanted.contains(t.id)) continue;
      final rel = t.texturePath;
      if (rel.isEmpty) continue;
      if (_editorTilesetImages.containsKey(rel) || _editorTilesetLoading.contains(rel)) {
        continue;
      }
      _editorTilesetLoading.add(rel);
      unawaited(_loadEditorTileset(root, rel));
    }
  }

  Future<void> _loadEditorTileset(String root, String rel) async {
    try {
      final f = File(p.join(root, rel));
      if (!await f.exists()) return;
      final bytes = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _editorTilesetImages[rel] = frame.image;
        _editorTilesetLoading.remove(rel);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _editorTilesetLoading.remove(rel));
      }
    }
  }

  String? _collabDisplayName(AuthProvider auth) {
    final u = auth.user;
    if (u == null) return null;
    final nick = u.nickname.trim();
    if (nick.isNotEmpty) return nick;
    final full = u.fullName.trim();
    if (full.isNotEmpty) return full;
    final em = u.email.trim();
    if (em.contains('@')) return em.split('@').first;
    return em.isNotEmpty ? em : null;
  }

  void _throttledPresence(
    BuildContext context,
    SceneProvider sceneProvider,
    ProjectManager manager,
    Offset local,
  ) {
    sceneProvider.setLastEditorPointerLocal(local);
    if (!manager.hasActiveSceneCollab) return;
    final scene = sceneProvider.currentScene;
    if (scene == null) return;
    final now = DateTime.now();
    if (now.difference(_lastPresenceSent).inMilliseconds < 90) return;
    _lastPresenceSent = now;
    final auth = context.read<AuthProvider>();
    manager.sendCollabPresence(
      sceneId: scene.id,
      x: local.dx,
      y: local.dy,
      selectedObjectId: sceneProvider.selectedObjectId,
      displayName: _collabDisplayName(auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SceneProvider, ProjectManager>(
      builder: (context, sceneProvider, manager, child) {
        if (sceneProvider.currentScene == null) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No scene loaded', style: TextStyle(color: Colors.grey)),
                SizedBox(height: 8),
                Text(
                  'Create a new scene in the project tree',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }
        final scene = sceneProvider.currentScene!;
        _ensureEditorTilesetImages(scene, manager);
        final paintOrder = sceneObjectsPaintOrder(scene);
        final assets = manager.assets;
        final selectedId = sceneProvider.selectedObjectId;
        final tilesetCatalogJson =
            manager.projectSettings?.tilesets.map((t) => t.toJson()).toList() ?? const <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SceneScenesTabBar(),
            const TilemapEditorToolbar(),
            const SceneCanvasOptionsBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return MouseRegion(
                cursor: sceneProvider.tileEditMode
                    ? SystemMouseCursors.cell
                    : _canvasPanning
                        ? SystemMouseCursors.grabbing
                        : SystemMouseCursors.grab,
                onHover: (e) {
                  _lastZoomFocal = e.localPosition;
                  _throttledPresence(
                    context, sceneProvider, manager, _scenePointFromViewport(e.localPosition));
                },
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      if (event.kind == PointerDeviceKind.trackpad ||
                          HardwareKeyboard.instance.isControlPressed) {
                        final scaleDelta = 1 - event.scrollDelta.dy * 0.002;
                        final focal = event.localPosition;
                        final m = Matrix4.copy(_viewportTransform.value);
                        m.translate(focal.dx, focal.dy);
                        m.scale(scaleDelta.clamp(0.85, 1.15));
                        m.translate(-focal.dx, -focal.dy);
                        _viewportTransform.value = m;
                      } else {
                        _panCanvasBy(-event.scrollDelta);
                      }
                    }
                  },
                  child: InteractiveViewer(
                    transformationController: _viewportTransform,
                    minScale: 0.15,
                    maxScale: 4,
                    panEnabled: false,
                    scaleEnabled: false,
                    boundaryMargin: const EdgeInsets.all(480),
                    child: DragTarget<String>(
                      onWillAccept: (data) => !sceneProvider.tileEditMode,
                      onAcceptWithDetails: (details) {
                        if (sceneProvider.tileEditMode) return;
                        final assetId = details.data;

                        final asset = assets.where((a) => a.id == assetId).toList();
                        if (asset.isEmpty) return;
                        if (asset.first.type != 'sprite') return;

                        final local = sceneProvider.lastEditorPointerLocal ??
                            const Offset(200, 200);
                        final st = sceneProvider.objectSnapStep;
                        final pos = Offset(
                          _snapToStep(local.dx, st),
                          _snapToStep(local.dy, st),
                        );

                        final objId = 'obj_${DateTime.now().millisecondsSinceEpoch}';
                        final spriteObj = SceneObject(
                          id: objId,
                          name: asset.first.name,
                          assetId: asset.first.id,
                          x: pos.dx,
                          y: pos.dy,
                          layerId: SceneLayer.defaultLayerId,
                        );

                        sceneProvider.addObject(spriteObj);
                        sceneProvider.selectObject(spriteObj.id);
                        manager.scheduleSceneSave();
                      },
                      builder: (context, candidateData, rejectedData) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (details) {
                            final scenePos = details.localPosition;
                            sceneProvider.setLastEditorPointerLocal(scenePos);
                            if (sceneProvider.tileEditMode) {
                              if (!_tileStrokeUndoPushed) {
                                sceneProvider.pushUndoSnapshot();
                                _tileStrokeUndoPushed = true;
                              }
                              sceneProvider.paintTileAtEditor(scenePos.dx, scenePos.dy);
                              Provider.of<ProjectManager>(context, listen: false)
                                  .scheduleSceneSave();
                              return;
                            }
                            _throttledPresence(
                                context, sceneProvider, manager, scenePos);
                            SceneObject? hit;
                            for (final object in paintOrder.reversed) {
                              if (!object.active || !object.visible) continue;
                              final w = object.width * object.scaleX;
                              final h = object.height * object.scaleY;
                              final rect = Rect.fromCenter(
                                center: Offset(object.x, object.y),
                                width: w,
                                height: h,
                              );
                              if (rect.contains(scenePos)) {
                                hit = object;
                                break;
                              }
                            }
                            sceneProvider.selectObject(hit?.id);
                            if (hit == null || hit.locked) {
                              setState(() {
                                _draggedObjectId = null;
                                _dragOffset = null;
                                _isDragging = false;
                                _canvasPanning = hit == null;
                                _canvasPanAnchor = details.localPosition;
                              });
                              return;
                            }
                            setState(() {
                              _draggedObjectId = hit!.id;
                              _dragOffset = Offset(
                                hit.x - scenePos.dx,
                                hit.y - scenePos.dy,
                              );
                              _isDragging = true;
                              _canvasPanning = false;
                              _canvasPanAnchor = null;
                            });
                            sceneProvider.pushUndoSnapshot();
                          },
                          onPanUpdate: (details) {
                            final scenePos = details.localPosition;
                            sceneProvider.setLastEditorPointerLocal(scenePos);
                            if (sceneProvider.tileEditMode) {
                              sceneProvider.paintTileAtEditor(scenePos.dx, scenePos.dy);
                              Provider.of<ProjectManager>(context, listen: false)
                                  .scheduleSceneSave();
                              return;
                            }
                            if (_canvasPanning && _canvasPanAnchor != null) {
                              final delta = details.localPosition - _canvasPanAnchor!;
                              _canvasPanAnchor = details.localPosition;
                              _panCanvasBy(delta);
                              return;
                            }
                            if (_draggedObjectId != null && _isDragging) {
                              final raw = scenePos + (_dragOffset ?? Offset.zero);
                              final st = sceneProvider.objectSnapStep;
                              sceneProvider.updateObjectPosition(
                                _draggedObjectId!,
                                _snapToStep(raw.dx, st),
                                _snapToStep(raw.dy, st),
                              );
                              _throttledPresence(
                                  context, sceneProvider, manager, scenePos);
                              Provider.of<ProjectManager>(context, listen: false)
                                  .scheduleSceneSave();
                            }
                          },
                          onPanCancel: () {
                            if (sceneProvider.tileEditMode) {
                              _tileStrokeUndoPushed = false;
                            }
                            setState(() {
                              _canvasPanning = false;
                              _canvasPanAnchor = null;
                            });
                          },
                          onPanEnd: (details) {
                            if (sceneProvider.tileEditMode) {
                              _tileStrokeUndoPushed = false;
                              Provider.of<ProjectManager>(context, listen: false)
                                  .scheduleSceneSave();
                              setState(() {
                                _canvasPanning = false;
                                _canvasPanAnchor = null;
                              });
                              return;
                            }
                            final id = _draggedObjectId;
                            final curScene = sceneProvider.currentScene;
                            if (id != null && curScene != null) {
                              final st = sceneProvider.objectSnapStep;
                              for (final o in curScene.objects) {
                                if (o.id == id) {
                                  sceneProvider.updateObjectPosition(
                                    id,
                                    _snapToStep(o.x, st),
                                    _snapToStep(o.y, st),
                                  );
                                  break;
                                }
                              }
                            }
                            Provider.of<ProjectManager>(context, listen: false)
                                .scheduleSceneSave();
                            setState(() {
                              _draggedObjectId = null;
                              _dragOffset = null;
                              _isDragging = false;
                              _canvasPanning = false;
                              _canvasPanAnchor = null;
                            });
                          },
                          onSecondaryTapDown: (details) {
                            setState(() {
                              _canvasPanning = true;
                              _canvasPanAnchor = details.localPosition;
                            });
                          },
                          child: RepaintBoundary(
                            child: SizedBox(
                              width: kSceneCanvasWidth,
                              height: kSceneCanvasHeight,
                              child: CustomPaint(
                                painter: ScenePainter(
                                  scene: scene,
                                  paintOrder: paintOrder,
                                  assets: assets,
                                  selectedObjectId: selectedId,
                                  tileEditorRevision: sceneProvider.tileEditorRevision,
                                  showRoomZones: sceneProvider.showRoomZones,
                                  showSceneGrid: sceneProvider.showSceneGrid,
                                  gridStep: sceneProvider.objectSnapStep > 0
                                      ? sceneProvider.objectSnapStep
                                      : kSceneEditorGridStep,
                                  showTileCollisionPreview:
                                      sceneProvider.showTileCollisionPreview,
                                  collabRemoteByUser: manager.collabRemotePointers,
                                  collabPresenceRevision: manager.collabPresenceRevision,
                                  tilesetCatalog: tilesetCatalogJson,
                                  tilemapTextures: _editorTilesetImages,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class ScenePainter extends CustomPainter {
  final Scene scene;
  final List<SceneObject> paintOrder;
  final List<ProjectAsset> assets;
  final String? selectedObjectId;
  final int tileEditorRevision;
  final bool showRoomZones;
  final bool showSceneGrid;
  final double gridStep;
  final bool showTileCollisionPreview;
  final Map<String, CollabRemotePointer> collabRemoteByUser;
  final int collabPresenceRevision;
  final List<Map<String, dynamic>> tilesetCatalog;
  final Map<String, ui.Image> tilemapTextures;

  ScenePainter({
    required this.scene,
    required this.paintOrder,
    required this.assets,
    this.selectedObjectId,
    this.tileEditorRevision = 0,
    this.showRoomZones = false,
    this.showSceneGrid = true,
    this.gridStep = kSceneEditorGridStep,
    this.showTileCollisionPreview = true,
    this.collabRemoteByUser = const {},
    this.collabPresenceRevision = 0,
    this.tilesetCatalog = const [],
    this.tilemapTextures = const {},
  });

  Color _backgroundColor() {
    final c = scene.backgroundColorArgb;
    return Color(c);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _backgroundColor());

    final rustTilemaps = scene.tilemaps.map((l) => l.toRustJson()).toList();
    paintRustFormatTilemaps(
      canvas: canvas,
      viewSize: size,
      tilemaps: rustTilemaps,
      tilesetCatalog: tilesetCatalog,
      textureImages: tilemapTextures,
      worldToScreen: (wx, wy) => Offset(wx, wy),
      zoom: 1.0,
      collisionTintInEditor: showTileCollisionPreview,
    );

    final gridPaintMinor = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    final gridPaintMajor = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 0.8;
    if (showSceneGrid) {
      final step = gridStep.clamp(1.0, 256.0);
      var lineIndex = 0;
      for (double x = 0; x < size.width; x += step) {
        final paint = lineIndex % 5 == 0 ? gridPaintMajor : gridPaintMinor;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        lineIndex++;
      }
      lineIndex = 0;
      for (double y = 0; y < size.height; y += step) {
        final paint = lineIndex % 5 == 0 ? gridPaintMajor : gridPaintMinor;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        lineIndex++;
      }
      final origin = Paint()
        ..color = const Color(0xFFE11D48).withValues(alpha: 0.55)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset.zero, Offset(size.width.clamp(0, 120), 0), origin);
      canvas.drawLine(Offset.zero, Offset(0, size.height.clamp(0, 120)), origin);
    }

    if (showRoomZones && scene.rooms.isNotEmpty) {
      paintRoomZonesEditor(canvas, scene.rooms);
    }

    for (final object in paintOrder) {
      if (!object.active || !object.visible) continue;

      final asset = assets.firstWhere(
        (a) => a.id == object.assetId,
        orElse: () => ProjectAsset(
          id: '',
          name: '',
          type: 'unknown',
          path: '',
          createdAt: DateTime.now(),
          modifiedAt: DateTime.now(),
        ),
      );

      final w = object.width * object.scaleX;
      final h = object.height * object.scaleY;
      final rect = Rect.fromCenter(
        center: Offset(object.x, object.y),
        width: w,
        height: h,
      );

      if (asset.type == 'sprite') {
        final paint = Paint()..color = Colors.blue.withValues(alpha: 0.7);
        canvas.drawRect(rect, paint);
      } else {
        final paint = Paint()..color = Colors.red.withValues(alpha: 0.5);
        canvas.drawRect(rect, paint);
      }

      final borderPaint = Paint()
        ..color = object.locked ? Colors.orange : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = object.id == selectedObjectId ? 2.5 : 1;
      canvas.drawRect(rect, borderPaint);

      final meta = _metaForObject(object, assets);
      if (meta != null && meta.colliderKind != SpriteColliderKind.none) {
        final box = computeColliderWorldAabb(object, meta);
        final colliderRect = Rect.fromCenter(
          center: Offset(box.centerX, box.centerY),
          width: box.width,
          height: box.height,
        );
        final cp = Paint()
          ..color = Colors.greenAccent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        if (meta.colliderKind == SpriteColliderKind.circle) {
          final r = box.width / 2;
          canvas.drawCircle(Offset(box.centerX, box.centerY), r, cp);
        } else {
          canvas.drawRect(colliderRect, cp);
        }
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: object.name,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left, rect.top - 14),
      );
    }

    _paintRemoteCollaboration(canvas, size);
  }

  void _paintRemoteCollaboration(Canvas canvas, Size size) {
    final now = DateTime.now();
    for (final remote in collabRemoteByUser.values) {
      if (now.difference(remote.updatedAt).inSeconds > 45) continue;

      final sid = remote.selectedObjectId;
      if (sid != null) {
        SceneObject? robj;
        for (final o in scene.objects) {
          if (o.id == sid) {
            robj = o;
            break;
          }
        }
        if (robj != null && robj.active && robj.visible) {
          final rw = robj.width * robj.scaleX;
          final rh = robj.height * robj.scaleY;
          final rrect = Rect.fromCenter(
            center: Offset(robj.x, robj.y),
            width: rw,
            height: rh,
          );
          final rp = Paint()
            ..color = remote.color.withValues(alpha: 0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRRect(
            RRect.fromRectXY(rrect.inflate(2), 4, 4),
            rp,
          );
        }
      }

      final cx = remote.x;
      final cy = remote.y;
      if (cx == null || cy == null) continue;
      if (cx < -80 || cy < -80 || cx > size.width + 80 || cy > size.height + 80) {
        continue;
      }
      final o = Offset(cx, cy);
      final lp = Paint()
        ..color = remote.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(o, 4, lp);
      canvas.drawLine(o + const Offset(-14, 0), o + const Offset(14, 0), lp);
      canvas.drawLine(o + const Offset(0, -14), o + const Offset(0, 14), lp);
      final tp = TextPainter(
        text: TextSpan(
          text: remote.displayLabel,
          style: TextStyle(
            color: remote.color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      tp.paint(canvas, o + const Offset(10, -20));
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) {
    return oldDelegate.scene != scene ||
        oldDelegate.paintOrder != paintOrder ||
        oldDelegate.assets != assets ||
        oldDelegate.selectedObjectId != selectedObjectId ||
        oldDelegate.tileEditorRevision != tileEditorRevision ||
        oldDelegate.showRoomZones != showRoomZones ||
        oldDelegate.showSceneGrid != showSceneGrid ||
        oldDelegate.gridStep != gridStep ||
        oldDelegate.showTileCollisionPreview != showTileCollisionPreview ||
        oldDelegate.collabPresenceRevision != collabPresenceRevision ||
        oldDelegate.tilesetCatalog != tilesetCatalog ||
        oldDelegate.tilemapTextures != tilemapTextures;
  }
}
