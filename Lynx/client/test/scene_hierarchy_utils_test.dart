import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/scene_hierarchy_utils.dart';
import 'package:flutter_test/flutter_test.dart';

SceneObject obj(String id, {String? parentId}) {
  return SceneObject(
    id: id,
    name: id,
    x: 0,
    y: 0,
    z: 0,
    width: 10,
    height: 10,
    rotation: 0,
    scaleX: 1,
    scaleY: 1,
    originX: 0.5,
    originY: 0.5,
    parentId: parentId,
    layerId: null,
    assetId: 'test',
    scriptId: null,
    active: true,
    visible: true,
    locked: false,
    prefabId: null,
    properties: const {},
  );
}

void main() {
  test('wouldCreateParentCycle: self and descendant', () {
    final a = obj('a');
    final b = obj('b', parentId: 'a');
    final c = obj('c', parentId: 'b');
    final objects = [a, b, c];

    expect(wouldCreateParentCycle(objects, 'a', 'a'), true);
    expect(wouldCreateParentCycle(objects, 'b', 'b'), true);
    expect(wouldCreateParentCycle(objects, 'c', 'c'), true);

    expect(wouldCreateParentCycle(objects, 'a', 'c'), true);
    expect(wouldCreateParentCycle(objects, 'a', 'b'), true);

    expect(wouldCreateParentCycle(objects, 'c', 'a'), false);
    expect(wouldCreateParentCycle(objects, 'b', 'a'), false);
  });

  test('validParentCandidates excludes self and subtree', () {
    final a = obj('a');
    final b = obj('b', parentId: 'a');
    final cN = obj('c', parentId: 'b');
    final dN = obj('d');
    final scene = Scene(
      id: 's',
      name: 's',
      objects: [a, b, cN, dN],
      layers: Scene.defaultLayers(),
      createdAt: DateTime(2020),
      modifiedAt: DateTime(2020),
    );

    final forB = validParentCandidates(scene, 'b');
    expect(forB.map((e) => e.id).toSet(), {'a', 'd'});

    final forA = validParentCandidates(scene, 'a');
    expect(forA.map((e) => e.id).toSet(), {'d'});
  });
}
