import 'package:flutter/material.dart';

import 'lynx_3d_codec.dart';
import 'lynx_3d_mesh_cache.dart';
import 'lynx_3d_projection.dart';
import 'lynx_3d_viewport_painter.dart';
import 'lynx_glb_mesh.dart';

/// Viewport 3D с подгрузкой GLB-мешей из проекта.
class Lynx3dViewportCanvas extends StatefulWidget {
  const Lynx3dViewportCanvas({
    super.key,
    required this.extension,
    required this.camera,
    this.projectRoot,
    this.showGrid = true,
    this.child,
  });

  final Lynx3dSceneExtension extension;
  final Lynx3dOrbitCamera camera;
  final String? projectRoot;
  final bool showGrid;
  final Widget? child;

  @override
  State<Lynx3dViewportCanvas> createState() => _Lynx3dViewportCanvasState();
}

class _Lynx3dViewportCanvasState extends State<Lynx3dViewportCanvas> {
  late Lynx3dMeshCache _cache;
  Map<String, LynxGlbMesh> _meshes = {};
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    _cache = Lynx3dMeshCache(projectRoot: widget.projectRoot);
    _reloadMeshes();
  }

  @override
  void didUpdateWidget(covariant Lynx3dViewportCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension != widget.extension ||
        oldWidget.projectRoot != widget.projectRoot) {
      _cache.projectRoot = widget.projectRoot;
      _reloadMeshes();
    }
  }

  Future<void> _reloadMeshes() async {
    final gen = ++_loadGen;
    final paths = widget.extension.objects.map((o) => o.mesh).toList();
    final loaded = await _cache.loadForMeshes(paths);
    if (!mounted || gen != _loadGen) return;
    setState(() => _meshes = loaded);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: Lynx3dViewportPainter(
        extension: widget.extension,
        camera: widget.camera,
        meshesByPath: _meshes,
        showGrid: widget.showGrid,
      ),
      child: widget.child ?? const SizedBox.expand(),
    );
  }
}
