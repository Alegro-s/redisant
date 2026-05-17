import 'package:client/features/engine/collab/collab_presence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CollabRemotePointer.fromMessage parses cursor and selection', () {
    final p = CollabRemotePointer.fromMessage({
      'fromUserId': 'user-1',
      'cursor': {'x': 12.5, 'y': 30.0},
      'selectedObjectId': 'obj_x',
    });
    expect(p, isNotNull);
    expect(p!.userId, 'user-1');
    expect(p.x, 12.5);
    expect(p.y, 30.0);
    expect(p.selectedObjectId, 'obj_x');
  });

  test('CollabRemotePointer.fromMessage parses displayName', () {
    final p = CollabRemotePointer.fromMessage({
      'fromUserId': 'u2',
      'displayName': '  Игорь  ',
      'cursor': {'x': 0.0, 'y': 0.0},
    });
    expect(p, isNotNull);
    expect(p!.displayName, '  Игорь  ');
    expect(p.displayLabel, 'Игорь');
  });

  test('CollabRemotePointer.fromMessage returns null without user id', () {
    expect(
      CollabRemotePointer.fromMessage({
        'cursor': {'x': 1.0, 'y': 2.0},
      }),
      isNull,
    );
  });

  test('mergeWithPrevious keeps cursor and name when partial update', () {
    final t0 = DateTime(2020);
    final prev = CollabRemotePointer(
      userId: 'peer',
      displayName: 'Peer',
      x: 10,
      y: 20,
      selectedObjectId: 'a',
      updatedAt: t0,
    );
    final next = CollabRemotePointer.fromMessage({
      'fromUserId': 'peer',
      'cursor': {'x': null, 'y': null},
      'hierarchyCollapsed': ['p1'],
    })!;
    final merged = CollabRemotePointer.mergeWithPrevious(next, prev);
    expect(merged.x, 10);
    expect(merged.y, 20);
    expect(merged.displayName, 'Peer');
    expect(merged.selectedObjectId, 'a');
  });

  test('parseHierarchyCollapsedIds', () {
    expect(parseHierarchyCollapsedIds(['a', 'b', '', 3]), {'a', 'b', '3'});
    expect(parseHierarchyCollapsedIds(null), <String>{});
    expect(parseHierarchyCollapsedIds('x'), <String>{});
  });

  test('simulated two-step sequence: pointer then hierarchy-only patch', () {
    final t0 = DateTime(2020);
    CollabRemotePointer? state;
    state = CollabRemotePointer.mergeWithPrevious(
      CollabRemotePointer.fromMessage({
        'fromUserId': 'A',
        'displayName': 'Alice',
        'cursor': {'x': 5.0, 'y': 6.0},
        'selectedObjectId': 'o1',
      })!,
      state,
    );
    expect(state!.x, 5);
    state = CollabRemotePointer.mergeWithPrevious(
      CollabRemotePointer.fromMessage({
        'fromUserId': 'A',
        'cursor': {},
      })!,
      state,
    );
    expect(state!.x, 5);
    expect(state.y, 6);
    expect(state.displayName, 'Alice');
    expect(state.selectedObjectId, 'o1');
  });
}
