import '../models/engine_models.dart';

SceneObject? _objectById(List<SceneObject> objects, String id) {
  for (final o in objects) {
    if (o.id == id) return o;
  }
  return null;
}

bool isAncestorOf(List<SceneObject> objects, String ancestorId, String startId) {
  String? walk = startId;
  final seen = <String>{};
  while (walk != null) {
    if (walk == ancestorId) return true;
    if (!seen.add(walk)) return false;
    walk = _objectById(objects, walk)?.parentId;
  }
  return false;
}

bool wouldCreateParentCycle(List<SceneObject> objects, String childId, String? newParentId) {
  if (newParentId == null) return false;
  if (newParentId == childId) return true;
  return isAncestorOf(objects, childId, newParentId);
}

List<SceneObject> validParentCandidates(Scene scene, String childId) {
  return scene.objects.where((o) {
    if (o.id == childId) return false;
    return !isAncestorOf(scene.objects, childId, o.id);
  }).toList();
}
