import 'package:flutter_test/flutter_test.dart';

import 'package:client/features/engine/runtime/lynx_graph_compiler.dart';
import 'package:client/features/engine/runtime/lynx_graph_model.dart';

void main() {
  test('default player blueprint compiles to lynxscript', () {
    final doc = LynxGraphDocument.defaultPlayerController();
    final src = compileLynxGraphToScript(doc);
    expect(src.startsWith('#lynxscript'), isTrue);
    expect(src, contains('set_velocity(0, vy)'));
    expect(src, contains('if key_a then'));
    expect(src, contains('if action_pressed("jump") then'));
    expect(src, contains('function on_signal()'));
  });

  test('round-trip json model', () {
    final doc = LynxGraphDocument(
      statements: [LynxGraphStatement.setVelocity('-100', 'vy')],
    );
    final back = LynxGraphDocument.fromJson(doc.toJson());
    expect(back.statements.length, 1);
    expect(back.statements.first.vx, '-100');
  });
}
