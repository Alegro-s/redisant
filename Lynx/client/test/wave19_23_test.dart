import 'package:client/features/engine/runtime/asset_meta_v2.dart';
import 'package:client/features/engine/runtime/lynx_build_profiles.dart';
import 'package:client/features/engine/runtime/lynx_export.dart';
import 'package:client/features/engine/runtime/lynx_web_runtime.dart';
import 'package:client/features/engine/runtime/unified_play_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase III wave 19-23', () {
    test('LynxBuildProfile maps to export preset and steps', () {
      expect(LynxBuildProfile.cart.exportPreset, LynxExportPreset.cart);
      expect(LynxBuildProfile.android.progressSteps, 6);
      expect(LynxBuildProfile.cart.progressSteps, 3);
    });

    test('LynxAssetMetaV2 roundtrip', () {
      final meta = LynxAssetMetaV2(
        assetPath: 'assets/sprites/hero.png',
        guid: 'abc',
        sourceHash: 'deadbeef',
        labels: const ['player'],
      );
      final back = LynxAssetMetaV2.fromJson(meta.toJson(), assetPath: meta.assetPath);
      expect(back.metaVersion, 2);
      expect(back.guid, 'abc');
      expect(back.labels, ['player']);
    });

    test('UnifiedPlayViewport snapshot pixel-perfect letterbox', () {
      final snap = unifiedViewportSnapshot(
        designWidth: 480,
        designHeight: 640,
        pixelPerfect: true,
        hostWidth: 960,
        hostHeight: 640,
      );
      expect(snap['scale'], closeTo(1.0, 0.001));
      expect(snap['viewportWidth'], 480);
      expect(snap['viewportHeight'], 640);
    });

    test('resolvePlayScale integer upscale for cart', () {
      final scale = UnifiedPlayViewport.resolvePlayScale(
        maxWidth: 1000,
        maxHeight: 800,
        designWidth: 480,
        designHeight: 640,
        pixelPerfect: true,
      );
      expect(scale, 1.0);
      final scale2 = UnifiedPlayViewport.resolvePlayScale(
        maxWidth: 2000,
        maxHeight: 1600,
        designWidth: 480,
        designHeight: 640,
        pixelPerfect: true,
      );
      expect(scale2, 2.0);
    });

    test('webRuntime wasm_core maps to LynxWebRuntime.wasmCore', () {
      expect(
        LynxWebRuntimeJson.fromJson('wasm_core_stub'),
        LynxWebRuntime.wasmCore,
      );
      expect(LynxWebRuntime.wasmCore.jsonValue, 'wasm_core');
    });
  });
}
