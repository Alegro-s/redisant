import 'package:client/features/engine/collab/script_studio_presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ScriptStudioRemote.tryParse', () {
    final r = ScriptStudioRemote.tryParse({
      'fromUserId': 'u1',
      'assetId': 'a1',
      'displayName': 'Alex',
      'line': 3,
      'column': 12,
    });
    expect(r, isNotNull);
    expect(r!.cloudAssetId, 'a1');
    expect(r.line, 3);
    expect(r.column, 12);
    expect(r.label, 'Alex');
  });
}
