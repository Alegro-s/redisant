import 'lynx_core_probe.dart';

/// E26 — unified render path selection (Core batch2d / forward3d vs Flutter Canvas).
class LynxUnifiedRenderCapabilities {
  const LynxUnifiedRenderCapabilities({
    required this.coreBatch2d,
    required this.coreForward3d,
    required this.flutterCanvasFallback,
  });

  final bool coreBatch2d;
  final bool coreForward3d;
  final bool flutterCanvasFallback;

  bool get preferCoreBatch2d => coreBatch2d;
  bool get preferCoreForward3d => coreForward3d;

  String get renderPathLabel {
    if (coreForward3d) return 'lynx-core:forward3d+batch2d';
    if (coreBatch2d) return 'lynx-core:batch2d';
    if (flutterCanvasFallback) return 'flutter:canvas';
    return 'unknown';
  }

  static const degradedWeb = LynxUnifiedRenderCapabilities(
    coreBatch2d: false,
    coreForward3d: false,
    flutterCanvasFallback: true,
  );
}

Future<LynxUnifiedRenderCapabilities> probeUnifiedRenderCapabilities() async {
  final core = await probeInstalledLynxCore();
  if (core == null) {
    return LynxUnifiedRenderCapabilities.degradedWeb;
  }
  // API v5+ — Core 1.0 ships batch2d + physics/audio FFI; 3D when D3D12 PAL present.
  final has3d = core.apiVersion >= 4;
  return LynxUnifiedRenderCapabilities(
    coreBatch2d: true,
    coreForward3d: has3d,
    flutterCanvasFallback: true,
  );
}
