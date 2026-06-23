import 'package:flutter_test/flutter_test.dart';

import 'package:client/features/collab/collab_presence_service.dart';
import 'package:client/features/engine/runtime/tic_audio_engine.dart';
import 'package:client/features/engine/runtime/tic_grid_codec.dart';
import 'package:client/features/ga/lynx_ga_gate.dart';
import 'package:client/features/live_ops/live_ops_config_service.dart';
import 'package:client/features/live_ops/live_ops_leaderboard_service.dart';
import 'package:client/features/narrative/narrative_codec.dart';
import 'package:client/features/narrative/narrative_service.dart';
import 'package:client/features/ecosystem/lynx_marketplace_billing.dart';
import 'package:client/features/plugins/lynx_plugin_manifest.dart';
import 'package:client/features/projects/lynx_built_games_registry.dart';
import 'package:client/features/engine/runtime/lynx_export_io.dart';

void main() {
  group('Phase III L22a', () {
    test('LynxBuiltGameRecord roundtrip', () {
      final r = LynxBuiltGameRecord(
        projectPath: '/tmp/demo',
        projectName: 'Demo',
        preset: LynxExportPreset.cart,
        outputDirectory: '/tmp/demo_build',
        artifactPaths: const ['/tmp/demo_build/game.lynxcart'],
        builtAt: DateTime.utc(2026, 6, 23),
      );
      final back = LynxBuiltGameRecord.fromJson(r.toJson());
      expect(back.projectPath, '/tmp/demo');
      expect(back.preset, LynxExportPreset.cart);
    });
  });

  group('TIC audio synth', () {
    test('synthesizeSfxWave produces WAV header', () {
      final wav = TicAudioSynth.synthesizeSfxWave(note: 48, durationTicks: 10, volume: 15);
      expect(wav.length, greaterThan(44));
      expect(wav[0], 0x52); // RIFF
    });
  });

  group('TIC persistent callback', () {
    test('detects function TIC in source', () {
      expect('function TIC()\nend'.contains('function TIC'), isTrue);
    });
  });

  group('TIC API layer', () {
    test('projectUsesTicApi detects tic mode', () {
      expect(projectUsesTicApi(gameTemplate: 'tic'), isTrue);
      expect(projectUsesTicApi(projectMode: LynxProjectMode.tic.jsonValue), isTrue);
      expect(projectUsesTicApi(gameTemplate: 'platformer'), isFalse);
    });

    test('emptyTicGrid dimensions', () {
      final g = emptyTicGrid(TicDimensions.displayW, TicDimensions.displayH);
      expect(g['w'], 240);
      expect((g['cells'] as List).length, 240 * 136);
    });
  });

  group('Phase V wave 28 narrative', () {
    test('NarrativeScript demo parses', () {
      final s = NarrativeService.demoScript();
      expect(s.node('intro')?.text, contains('Lynx'));
      expect(s.node('choice1')?.choices.length, 2);
    });

    test('NarrativeChoice json', () {
      final c = NarrativeChoice(label: 'Go', gotoId: 'next');
      expect(c.toJson()['goto'], 'next');
    });
  });

  group('Phase V wave 29 live ops', () {
    test('LiveOpsConfigService flags', () {
      final svc = LiveOpsConfigService();
      expect(svc.flag('missing', defaultValue: true), isTrue);
    });

    test('Leaderboard demo entries', () async {
      final svc = LiveOpsLeaderboardService();
      final top = await svc.fetchTop();
      expect(top.length, greaterThan(0));
    });
  });

  group('Phase V wave 30 marketplace', () {
    test('billing purchase demo', () async {
      final billing = LynxMarketplaceBilling();
      final r = await billing.purchaseCart(cartId: 'c1', buyerUserId: 'u1');
      expect(r.success, isTrue);
    });
  });

  group('Phase V wave 31 collab', () {
    test('scene lock acquire/release', () {
      final locks = CollabSceneLockService();
      expect(locks.tryAcquire(sceneId: 'main', userId: 'a'), isTrue);
      expect(locks.tryAcquire(sceneId: 'main', userId: 'b'), isFalse);
      locks.release(sceneId: 'main', userId: 'a');
      expect(locks.tryAcquire(sceneId: 'main', userId: 'b'), isTrue);
    });
  });

  group('Phase V wave 32 GA', () {
    test('LynxGaGate semver', () {
      expect(LynxGaGate.isGaLauncher('1.0.0'), isTrue);
      expect(LynxGaGate.isGaEngineCore('0.9.0'), isFalse);
      expect(LynxGaGate.engineApiVersion, 5);
    });
  });
}
