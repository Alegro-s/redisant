import 'package:client/features/engine/runtime/lynx_unified_render.dart';
import 'package:client/features/engine/runtime/lynx_web_runtime.dart';
import 'package:client/features/engine/runtime/nexus_engine_manifest.dart';
import 'package:client/features/engine/runtime/unified_play_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase IV wave 24-27', () {
    test('E24a LynxScript primary — wasm maps to wasmCore runtime', () {
      expect(LynxWebRuntimeJson.fromJson('wasm_core'), LynxWebRuntime.wasmCore);
      expect(LynxWebRuntime.wasmCore.jsonValue, 'wasm_core');
    });

    test('L24a manifest release parses size and changelog', () {
      final rel = NexusEngineReleaseInfo.fromJson({
        'version': '1.0.0',
        'notes': 'Core 1.0',
        'changelog': '- LynxScript\n- WASM',
        'sizeBytes': 42000000,
        'artifacts': {'windows': {'url': 'https://x/windows.lynxengine'}},
      });
      expect(rel.version, '1.0.0');
      expect(rel.sizeLabel, isNotEmpty);
      expect(rel.changelog, contains('WASM'));
    });

    test('E26 unified render prefers core batch when probed', () {
      const caps = LynxUnifiedRenderCapabilities(
        coreBatch2d: true,
        coreForward3d: false,
        flutterCanvasFallback: true,
      );
      expect(caps.preferCoreBatch2d, isTrue);
      expect(caps.renderPathLabel, contains('batch2d'));
    });

    test('E20b resolvePlayScale still valid after Phase IV', () {
      final scale = UnifiedPlayViewport.resolvePlayScale(
        maxWidth: 1920,
        maxHeight: 1080,
        designWidth: 480,
        designHeight: 640,
        pixelPerfect: true,
      );
      expect(scale, greaterThanOrEqualTo(1.0));
    });
  });
}
