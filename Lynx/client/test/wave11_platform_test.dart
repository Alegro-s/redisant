import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/engine_version_gate.dart';
import 'package:client/features/engine/runtime/lynx_web_runtime.dart';
import 'package:client/features/engine/runtime/lynx_windows_3d_runtime.dart';
import 'package:client/features/engine/runtime/web_script_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('engine version gate wave11', () {
    test('compareEngineVersions handles Lynx Core tags', () {
      expect(compareEngineVersions('0.6.0-m6', '0.5.0'), greaterThan(0));
      expect(compareEngineVersions('0.6.0-m6', '0.6.0-m6'), 0);
      expect(compareEngineVersions('0.6.0-m6', '0.6.0'), greaterThan(0));
    });
  });

  group('LynxWindows3dRuntime', () {
    test('fromJson defaults to canvas_preview', () {
      expect(
        LynxWindows3dRuntimeJson.fromJson(null),
        LynxWindows3dRuntime.canvasPreview,
      );
      expect(
        LynxWindows3dRuntimeJson.fromJson('core_forward_d3d12'),
        LynxWindows3dRuntime.coreForwardD3d12,
      );
    });

    test('GameProject round-trip windows3dRuntime', () {
      final gp = GameProject(
        projectId: 'p',
        displayName: 't',
        windows3dRuntime: LynxWindows3dRuntime.coreForwardD3d12,
      );
      final json = gp.toJson();
      expect(json['windows3dRuntime'], 'core_forward_d3d12');
      expect(
        GameProject.fromJson(json).windows3dRuntime,
        LynxWindows3dRuntime.coreForwardD3d12,
      );
    });
  });

  group('LynxWebRuntime', () {
    test('fromJson defaults to web_scene_engine', () {
      expect(LynxWebRuntimeJson.fromJson(null), LynxWebRuntime.webSceneEngine);
      expect(LynxWebRuntimeJson.fromJson('wasm_core_stub'), LynxWebRuntime.wasmCore);
    });

    test('GameProject round-trip webRuntime', () {
      final gp = GameProject(
        projectId: 'p',
        displayName: 't',
        minLynxCoreVersion: '0.6.0-m6',
        webRuntime: LynxWebRuntime.lynxCartRuntime,
      );
      final json = gp.toJson();
      expect(json['webRuntime'], 'lynx_cart_runtime');
      expect(json['minLynxCoreVersion'], '0.6.0-m6');
      final back = GameProject.fromJson(json);
      expect(back.webRuntime, LynxWebRuntime.lynxCartRuntime);
      expect(back.minLynxCoreVersion, '0.6.0-m6');
    });
  });

  group('web script runtime (wave4 parity)', () {
    test('load_scene from menu script', () {
      final ctx = WebScriptContext(
        actions: {'confirm': true},
        keys: const {},
        onGround: false,
        vx: 0,
        vy: 0,
        entityId: 1,
      );
      runWebEntityScript(
        'if action_confirm then load_scene("main") end',
        ctx,
        dt: 0.016,
      );
      expect(ctx.pendingSceneLoad, 'main');
    });
  });
}
