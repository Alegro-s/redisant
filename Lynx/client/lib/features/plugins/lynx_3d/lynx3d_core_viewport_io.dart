import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../engine/ffi/engine_bridge.dart';
import 'lynx_3d_codec.dart';
import 'lynx3d_play_runtime.dart';

/// D3D12 viewport поверх Flutter view (Windows Player Q3).
class Lynx3dCoreViewport extends StatefulWidget {
  const Lynx3dCoreViewport({
    super.key,
    required this.extension,
    required this.projectPath,
    this.orbitYaw = 0,
    this.orbitPitch = 0.35,
    this.simulatePhysics = true,
  });

  final Lynx3dSceneExtension extension;
  final String? projectPath;
  final double orbitYaw;
  final double orbitPitch;
  final bool simulatePhysics;

  static bool get isPlatformSupported =>
      !kIsWeb && Platform.isWindows && Lynx3dViewportFfi.isAvailable;

  @override
  State<Lynx3dCoreViewport> createState() => _Lynx3dCoreViewportState();
}

class _Lynx3dCoreViewportState extends State<Lynx3dCoreViewport>
    with SingleTickerProviderStateMixin {
  Pointer<Void>? _vp;
  late AnimationController _tick;
  late Lynx3dPlayRuntime _runtime;
  Lynx3dSceneExtension _liveExt = const Lynx3dSceneExtension(
    active: false,
    gravity: [0, -9.81, 0],
    ambientColor: '#404050',
    camera: Lynx3dCameraSettings(),
  );
  String? _initError;

  @override
  void initState() {
    super.initState();
    _liveExt = widget.extension;
    _runtime = Lynx3dPlayRuntime(
      extension: widget.extension,
      simulatePhysics: widget.simulatePhysics,
    );
    _tick = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick);
    if (widget.simulatePhysics) {
      _tick.repeat();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureViewport());
  }

  @override
  void didUpdateWidget(covariant Lynx3dCoreViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.extension != widget.extension) {
      _runtime.dispose();
      _runtime = Lynx3dPlayRuntime(
        extension: widget.extension,
        simulatePhysics: widget.simulatePhysics,
      );
      _liveExt = widget.extension;
      WidgetsBinding.instance.addPostFrameCallback((_) => _present());
    }
  }

  @override
  void dispose() {
    _runtime.dispose();
    _tick.dispose();
    Lynx3dViewportFfi.destroy(_vp);
    _vp = null;
    super.dispose();
  }

  void _onTick() {
    _liveExt = _runtime.tick(1 / 60.0);
    _present();
  }

  Future<void> _ensureViewport() async {
    if (_vp != null && _vp != nullptr) return;
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dpr = View.of(context).devicePixelRatio;
    final offset = box.localToGlobal(Offset.zero);
    final w = (box.size.width * dpr).round().clamp(64, 4096);
    final h = (box.size.height * dpr).round().clamp(64, 4096);
    final x = (offset.dx * dpr).round();
    final y = (offset.dy * dpr).round();
    try {
      final hwnd = await const MethodChannel('lynx/viewport')
          .invokeMethod<int>('getViewHwnd');
      if (hwnd == null || hwnd == 0) {
        setState(() => _initError = 'HWND недоступен');
        return;
      }
      final vp = Lynx3dViewportFfi.create(
        parentHwnd: hwnd,
        x: x,
        y: y,
        width: w,
        height: h,
      );
      if (vp == null || vp == nullptr) {
        setState(() => _initError = 'lynx_viewport_create failed');
        return;
      }
      setState(() {
        _vp = vp;
        _initError = null;
      });
      _present();
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  void _present() {
    final vp = _vp;
    if (vp == null || vp == nullptr) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final dpr = View.of(context).devicePixelRatio;
      final w = (box.size.width * dpr).round().clamp(64, 4096);
      final h = (box.size.height * dpr).round().clamp(64, 4096);
      Lynx3dViewportFfi.resize(vp, w, h);
    }
    final json = jsonEncode(_liveExt.toMap());
    Lynx3dViewportFfi.present(
      vp: vp,
      lynx3dJson: json,
      projectRoot: widget.projectPath,
      orbitYaw: widget.orbitYaw,
      orbitPitch: widget.orbitPitch,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Center(
        child: Text(
          'Core 3D: $_initError',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _ensureViewport());
        return const SizedBox.expand();
      },
    );
  }
}

class Lynx3dViewportFfi {
  static bool _checked = false;
  static bool _available = false;

  static bool get isAvailable {
    if (_checked) return _available;
    _checked = true;
    if (kIsWeb || !Platform.isWindows) return false;
    try {
      EngineBridge.init();
      final f = EngineBridge.lib
          .lookup<NativeFunction<Uint8 Function()>>('lynx_viewport_available');
      _available = f.asFunction<int Function()>() != 0;
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  static Pointer<Void>? create({
    required int parentHwnd,
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Pointer<Void> Function(IntPtr, Int32, Int32, Uint32, Uint32)>>(
          'lynx_viewport_create',
        )
        .asFunction<Pointer<Void> Function(int, int, int, int, int)>();
    return f(parentHwnd, x, y, width, height);
  }

  static void destroy(Pointer<Void>? vp) {
    if (vp == null || vp == nullptr) return;
    final f = EngineBridge.lib
        .lookup<NativeFunction<Void Function(Pointer<Void>)>>('lynx_viewport_destroy')
        .asFunction<void Function(Pointer<Void>)>();
    f(vp);
  }

  static void resize(Pointer<Void> vp, int width, int height) {
    final f = EngineBridge.lib
        .lookup<NativeFunction<Uint8 Function(Pointer<Void>, Uint32, Uint32)>>(
          'lynx_viewport_resize',
        )
        .asFunction<int Function(Pointer<Void>, int, int)>();
    f(vp, width, height);
  }

  static void present({
    required Pointer<Void> vp,
    required String lynx3dJson,
    required String? projectRoot,
    required double orbitYaw,
    required double orbitPitch,
  }) {
    final f = EngineBridge.lib
        .lookup<
            NativeFunction<
                Uint8 Function(
                  Pointer<Void>,
                  Pointer<Utf8>,
                  Pointer<Utf8>,
                  Float,
                  Float,
                )>>('lynx_viewport_present_lynx3d')
        .asFunction<
            int Function(
              Pointer<Void>,
              Pointer<Utf8>,
              Pointer<Utf8>,
              double,
              double,
            )>();
    final j = lynx3dJson.toNativeUtf8();
    final root = (projectRoot ?? '').toNativeUtf8();
    try {
      f(vp, j, root, orbitYaw, orbitPitch);
    } finally {
      calloc.free(j);
      calloc.free(root);
    }
  }
}
