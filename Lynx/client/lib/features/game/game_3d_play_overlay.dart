import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../plugins/lynx_3d/lynx_3d_codec.dart';
import '../plugins/lynx_3d/lynx_3d_projection.dart';
import '../plugins/lynx_3d/lynx_3d_viewport_canvas.dart';
import '../plugins/lynx_3d/lynx3d_play_runtime.dart';

/// Отрисовка 3D поверх 2D Play + Core/Dart физика (M14a).
class Game3dPlayOverlay extends StatefulWidget {
  const Game3dPlayOverlay({
    super.key,
    required this.extension,
    required this.simulatePhysics,
    this.projectPath,
  });

  final Lynx3dSceneExtension extension;
  final bool simulatePhysics;
  final String? projectPath;

  @override
  State<Game3dPlayOverlay> createState() => _Game3dPlayOverlayState();
}

class _Game3dPlayOverlayState extends State<Game3dPlayOverlay>
    with SingleTickerProviderStateMixin {
  final Lynx3dOrbitCamera _camera = Lynx3dOrbitCamera();
  late Lynx3dPlayRuntime _runtime;
  late AnimationController _tick;
  Lynx3dSceneExtension _renderExt = const Lynx3dSceneExtension(
    active: false,
    gravity: [0, -9.81, 0],
    ambientColor: '#404050',
    camera: Lynx3dCameraSettings(),
  );

  @override
  void initState() {
    super.initState();
    _camera.distance = widget.extension.camera.orbitDistance;
    _runtime = Lynx3dPlayRuntime(
      extension: widget.extension,
      simulatePhysics: widget.simulatePhysics,
    );
    _renderExt = widget.extension;
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick);
    if (widget.simulatePhysics && !kIsWeb) {
      _tick.repeat();
    }
  }

  @override
  void dispose() {
    _runtime.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!widget.simulatePhysics) return;
    _renderExt = _runtime.tick(1 / 60.0);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Align(
        alignment: Alignment.topCenter,
        child: Material(
          color: Colors.black54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '3D preview: упрощённый режим (без orbit)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Lynx3dViewportCanvas(
        extension: _renderExt,
        camera: _camera,
        projectRoot: widget.projectPath,
        showGrid: false,
      ),
    );
  }
}
