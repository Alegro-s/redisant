import 'package:client/features/engine/models/engine_models.dart';
import 'package:client/features/engine/runtime/prefab_baseline_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefabObjectsOrdered: root then child', () {
    final def = PrefabDefinition(
      id: 'p1',
      name: 'P',
      templateRoot: SceneObject(
        id: 'p_root',
        name: 'Root',
        assetId: 'a',
        x: 0,
        y: 0,
      ),
      children: [
        SceneObject(
          id: 'p_1',
          name: 'C',
          assetId: 'b',
          parentId: 'p_root',
          x: 10,
          y: 0,
        ),
      ],
    );
    final ord = prefabObjectsOrdered(def);
    expect(ord.length, 2);
    expect(ord[0].id, 'p_root');
    expect(ord[1].id, 'p_1');
  });

  test('prefabBaselineForInstance matches parallel subtree', () {
    final def = PrefabDefinition(
      id: 'p1',
      name: 'P',
      templateRoot: SceneObject(
        id: 'p_root',
        name: 'Root',
        assetId: 'spr',
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
      children: [
        SceneObject(
          id: 'p_1',
          name: 'Child',
          assetId: 'spr',
          parentId: 'p_root',
          x: 5,
          y: 5,
        ),
      ],
    );

    final instRoot = SceneObject(
      id: 'i0',
      name: 'Root',
      assetId: 'spr',
      x: 100,
      y: 200,
      width: 10,
      height: 10,
      prefabId: 'p1',
    );
    final instChild = SceneObject(
      id: 'i1',
      name: 'Child',
      assetId: 'spr',
      parentId: 'i0',
      x: 105,
      y: 205,
      prefabId: 'p1',
    );

    final scene = Scene(
      id: 's',
      name: 'S',
      objects: [instRoot, instChild],
      createdAt: DateTime.utc(2020),
      modifiedAt: DateTime.utc(2020),
    );

    final b0 = prefabBaselineForInstance(scene, instRoot, def);
    final b1 = prefabBaselineForInstance(scene, instChild, def);
    expect(b0?.id, 'p_root');
    expect(b1?.id, 'p_1');
  });

  test('revertInstanceToPrefabTemplate keeps ids', () {
    final inst = SceneObject(
      id: 'live',
      name: 'X',
      assetId: 'a',
      parentId: 'par',
      prefabId: 'p1',
      x: 99,
      y: 88,
    );
    final tpl = SceneObject(
      id: 'p_root',
      name: 'Root',
      assetId: 'b',
      x: 0,
      y: 0,
    );
    final r = revertInstanceToPrefabTemplate(inst, tpl);
    expect(r.id, 'live');
    expect(r.parentId, 'par');
    expect(r.prefabId, 'p1');
    expect(r.name, 'Root');
    expect(r.assetId, 'b');
    expect(r.x, 0);
    expect(r.y, 0);
  });
}
