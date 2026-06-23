import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/project_manager.dart';
import '../../engine/providers/scene_provider.dart';
import '../lynx_plugin_host.dart';
import '../lynx_plugin_manifest.dart';
import 'lynx_3d_codec.dart';
import 'lynx_3d_pick.dart';
import 'lynx_3d_projection.dart';
import 'lynx_3d_viewport_canvas.dart';

/// Редактор: orbit viewport 3D с выбором и перемещением объектов.
class Lynx3dEditorViewport extends StatefulWidget {
  const Lynx3dEditorViewport({super.key});

  @override
  State<Lynx3dEditorViewport> createState() => _Lynx3dEditorViewportState();
}

class _Lynx3dEditorViewportState extends State<Lynx3dEditorViewport> {
  final Lynx3dOrbitCamera _camera = Lynx3dOrbitCamera();
  String? _selectedId;
  bool _draggingObject = false;
  bool _orbitMode = true;

  void _commitObjectPosition(SceneProvider sp, String objectId, List<double> pos) {
    final scene = sp.currentScene;
    if (scene == null) return;
    for (var i = 0; i < scene.objects.length; i++) {
      final o = scene.objects[i];
      if (o.id != objectId) continue;
      final props = Map<String, dynamic>.from(o.properties);
      final block = Map<String, dynamic>.from(
        props[Lynx3dPluginIds.objectPropertyKey] as Map? ?? {},
      );
      block['position'] = pos;
      props[Lynx3dPluginIds.objectPropertyKey] = block;
      sp.updateObject(o.copyWith(properties: props));
      break;
    }
    Provider.of<ProjectManager>(context, listen: false).scheduleSceneSave();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '3D viewport в браузере недоступен (упрощённый режим).\n'
            'Используйте Windows/macOS/Linux для orbit-камеры.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Consumer<SceneProvider>(
      builder: (context, sp, _) {
        final scene = sp.currentScene;
        if (scene == null) {
          return const Center(child: Text('Нет открытой сцены'));
        }
        final ext = build3dExtensionFromScene(scene, LynxPluginHost.instance.context);
        _camera.distance = ext.camera.orbitDistance;
        final lookAt = ext.room?.center ?? [0, 2, 0];
        final fov = ext.camera.fovY;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.view_in_ar_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '3D · ${ext.objects.length} объект(ов)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const Spacer(),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Orbit'), icon: Icon(Icons.rotate_90_degrees_ccw_outlined, size: 16)),
                        ButtonSegment(value: false, label: Text('Move'), icon: Icon(Icons.open_with_outlined, size: 16)),
                      ],
                      selected: {_orbitMode},
                      onSelectionChanged: (s) => setState(() => _orbitMode = s.first),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return Listener(
                    onPointerSignal: (e) {
                      if (e is PointerScrollEvent && _orbitMode) {
                        setState(() => _camera.zoomBy(e.scrollDelta.dy * 0.02));
                      }
                    },
                    child: GestureDetector(
                      onTapDown: (d) {
                        if (_orbitMode) return;
                        final id = pickLynx3dObjectAt(
                          screen: d.localPosition,
                          size: viewSize,
                          extension: ext,
                          camera: _camera,
                        );
                        setState(() => _selectedId = id);
                        if (id != null) sp.selectObject(id);
                      },
                      onPanStart: (_) {
                        if (!_orbitMode && _selectedId != null) {
                          _draggingObject = true;
                        }
                      },
                      onPanUpdate: (d) {
                        if (_orbitMode) {
                          setState(() => _camera.rotateBy(d.delta.dx, d.delta.dy));
                          return;
                        }
                        if (!_draggingObject || _selectedId == null) return;
                        for (final obj in ext.objects) {
                          if (obj.id != _selectedId) continue;
                          final next = dragLynx3dObjectOnPlane(
                            screenDelta: d.delta,
                            size: viewSize,
                            position: obj.position,
                            camera: _camera,
                            lookAt: lookAt,
                            fovYDeg: fov,
                          );
                          _commitObjectPosition(sp, _selectedId!, next);
                          setState(() {});
                          break;
                        }
                      },
                      onPanEnd: (_) => _draggingObject = false,
                      child: Lynx3dViewportCanvas(
                        extension: ext,
                        camera: _camera,
                        projectRoot: LynxPluginHost.instance.context?.projectRoot,
                        child: _selectedId == null
                            ? null
                            : CustomPaint(
                                painter: _SelectionHintPainter(
                                  selectedId: _selectedId!,
                                  extension: ext,
                                  camera: _camera,
                                  viewSize: viewSize,
                                ),
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

class _SelectionHintPainter extends CustomPainter {
  _SelectionHintPainter({
    required this.selectedId,
    required this.extension,
    required this.camera,
    required this.viewSize,
  });

  final String selectedId;
  final Lynx3dSceneExtension extension;
  final Lynx3dOrbitCamera camera;
  final Size viewSize;

  @override
  void paint(Canvas canvas, Size size) {
    final lookAt = extension.room?.center ?? [0, 2, 0];
    final fov = extension.camera.fovY;
    for (final obj in extension.objects) {
      if (obj.id != selectedId) continue;
      final p = camera.project(obj.position, size: viewSize, lookAt: lookAt, fovYDeg: fov);
      final paint = Paint()
        ..color = const Color(0xFF22D3EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(p, 14, paint);
      break;
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionHintPainter old) =>
      old.selectedId != selectedId || old.extension != extension;
}
