import 'package:client/features/engine/runtime/engine_version_gate.dart';
import 'package:client/features/engine/runtime/web_script_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('engine version gate', () {
    test('compareEngineVersions orders correctly', () {
      expect(compareEngineVersions('1.0.0', '0.9.9'), greaterThan(0));
      expect(compareEngineVersions('0.1.0', '0.1.0'), 0);
      expect(compareEngineVersions('0.1', '0.1.0'), 0);
    });
  });

  group('web script runtime', () {
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

    test('platformer velocity script', () {
      final ctx = WebScriptContext(
        actions: {'move_left': true, 'move_right': false, 'jump': false},
        keys: {'key_a': true, 'key_d': false, 'key_space': false},
        onGround: true,
        vx: 0,
        vy: 100,
        entityId: 2,
      );
      const code = '''
local speed = 260
local jump = 520
local nvx = 0
local nvy = vy
if action_move_left or key_a then nvx = -speed end
if action_move_right or key_d then nvx = speed end
if (action_jump or key_space) and on_ground then nvy = -jump end
set_velocity(nvx, nvy)
''';
      runWebEntityScript(code, ctx, dt: 0.016);
      expect(ctx.newVx, -260);
      expect(ctx.newVy, 100);
    });

    test('jump when action_jump', () {
      final ctx = WebScriptContext(
        actions: {'jump': true},
        keys: const {},
        onGround: true,
        vx: 0,
        vy: 50,
        entityId: 2,
      );
      runWebEntityScript(
        'local jump = 520\nlocal nvy = vy\nif action_jump and on_ground then nvy = -jump end\nset_velocity(0, nvy)',
        ctx,
        dt: 0.016,
      );
      expect(ctx.newVy, -520);
    });
  });
}
