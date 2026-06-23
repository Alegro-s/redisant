/// Wave 31 — presence + scene locks for cloud co-edit.
class CollabPresenceUser {
  final String userId;
  final String displayName;
  final String? sceneId;
  final DateTime lastSeen;

  const CollabPresenceUser({
    required this.userId,
    required this.displayName,
    this.sceneId,
    required this.lastSeen,
  });
}

class CollabPresenceService {
  final Map<String, CollabPresenceUser> _online = {};

  List<CollabPresenceUser> usersInProject(String projectId) =>
      _online.values.where((u) => true).toList();

  void heartbeat({
    required String projectId,
    required String userId,
    required String displayName,
    String? activeSceneId,
  }) {
    _online[userId] = CollabPresenceUser(
      userId: userId,
      displayName: displayName,
      sceneId: activeSceneId,
      lastSeen: DateTime.now(),
    );
  }

  void leave(String userId) => _online.remove(userId);
}

class CollabSceneLock {
  final String sceneId;
  final String userId;
  final DateTime acquiredAt;

  const CollabSceneLock({
    required this.sceneId,
    required this.userId,
    required this.acquiredAt,
  });
}

class CollabSceneLockService {
  final Map<String, CollabSceneLock> _locks = {};

  CollabSceneLock? lockForScene(String sceneId) => _locks[sceneId];

  bool tryAcquire({required String sceneId, required String userId}) {
    final existing = _locks[sceneId];
    if (existing != null && existing.userId != userId) return false;
    _locks[sceneId] = CollabSceneLock(
      sceneId: sceneId,
      userId: userId,
      acquiredAt: DateTime.now(),
    );
    return true;
  }

  void release({required String sceneId, required String userId}) {
    final existing = _locks[sceneId];
    if (existing?.userId == userId) {
      _locks.remove(sceneId);
    }
  }
}
