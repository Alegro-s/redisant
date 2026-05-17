import '../models/engine_models.dart';

List<SceneObject> prefabObjectsOrdered(PrefabDefinition def) {
  final root = def.templateRoot;
  final rest = List<SceneObject>.from(def.children);
  final sorted = <SceneObject>[root];
  while (rest.isNotEmpty) {
    final i = rest.indexWhere((c) => sorted.any((s) => s.id == c.parentId));
    if (i < 0) {
      sorted.addAll(rest);
      break;
    }
    sorted.add(rest.removeAt(i));
  }
  return sorted;
}

SceneObject? prefabInstanceRoot(Scene scene, SceneObject o) {
  if (o.prefabId == null) return null;
  var cur = o;
  for (;;) {
    final pid = cur.parentId;
    if (pid == null) return cur;
    SceneObject? p;
    for (final x in scene.objects) {
      if (x.id == pid) {
        p = x;
        break;
      }
    }
    if (p == null || p.prefabId != o.prefabId) return cur;
    cur = p;
  }
}

SceneObject? prefabBaselineForInstance(
  Scene scene,
  SceneObject o,
  PrefabDefinition def,
) {
  final root = prefabInstanceRoot(scene, o);
  if (root == null || root.prefabId != def.id) return null;

  if (o.id == root.id) {
    return def.templateRoot;
  }

  final orderedScene = collectSceneSubtreeOrdered(scene, root);
  final orderedPrefab = prefabObjectsOrdered(def);
  if (orderedScene.length != orderedPrefab.length) return null;
  final idx = orderedScene.indexWhere((x) => x.id == o.id);
  if (idx < 0 || idx >= orderedPrefab.length) return null;
  return orderedPrefab[idx];
}

bool _near(double a, double b, [double eps = 1e-4]) => (a - b).abs() < eps;

bool _propValEq(Object? a, Object? b) {
  if (a == b) return true;
  if (a is num && b is num) return a.toDouble() == b.toDouble();
  return false;
}

bool prefabPropertiesEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key)) return false;
    if (!_propValEq(e.value, b[e.key])) return false;
  }
  return true;
}

List<String> prefabDiffLabels(SceneObject inst, SceneObject baseline) {
  final out = <String>[];
  if (inst.name != baseline.name) out.add('Имя');
  if (inst.assetId != baseline.assetId) out.add('Спрайт');
  if (inst.layerId != baseline.layerId) out.add('Слой сцены');
  if (inst.scriptId != baseline.scriptId) out.add('Скрипт');
  if (!_near(inst.x, baseline.x) || !_near(inst.y, baseline.y)) {
    out.add('Позиция');
  }
  if (!_near(inst.z, baseline.z)) out.add('Z');
  if (!_near(inst.width, baseline.width) || !_near(inst.height, baseline.height)) {
    out.add('Размер');
  }
  if (!_near(inst.rotation, baseline.rotation)) out.add('Поворот');
  if (!_near(inst.scaleX, baseline.scaleX) || !_near(inst.scaleY, baseline.scaleY)) {
    out.add('Масштаб');
  }
  if (!_near(inst.originX, baseline.originX) || !_near(inst.originY, baseline.originY)) {
    out.add('Origin');
  }
  if (inst.active != baseline.active) out.add('Активен');
  if (inst.visible != baseline.visible) out.add('Видимый');
  if (inst.locked != baseline.locked) out.add('Заблокирован');
  if (!prefabPropertiesEqual(inst.properties, baseline.properties)) {
    out.add('Свойства');
  }
  return out;
}

SceneObject revertInstanceToPrefabTemplate(
  SceneObject instance,
  SceneObject baselineTemplate,
) {
  return instance.copyWith(
    name: baselineTemplate.name,
    assetId: baselineTemplate.assetId,
    x: baselineTemplate.x,
    y: baselineTemplate.y,
    z: baselineTemplate.z,
    width: baselineTemplate.width,
    height: baselineTemplate.height,
    rotation: baselineTemplate.rotation,
    scaleX: baselineTemplate.scaleX,
    scaleY: baselineTemplate.scaleY,
    originX: baselineTemplate.originX,
    originY: baselineTemplate.originY,
    active: baselineTemplate.active,
    visible: baselineTemplate.visible,
    locked: baselineTemplate.locked,
    layerId: baselineTemplate.layerId,
    scriptId: baselineTemplate.scriptId,
    properties: Map<String, dynamic>.from(baselineTemplate.properties),
    propertyOverrides: const {},
  );
}
