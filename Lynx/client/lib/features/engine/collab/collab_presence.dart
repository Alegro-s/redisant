import 'package:flutter/material.dart';

class CollabRemotePointer {
  CollabRemotePointer({
    required this.userId,
    this.displayName,
    this.x,
    this.y,
    this.selectedObjectId,
    required this.updatedAt,
  });

  final String userId;
  final String? displayName;
  final double? x;
  final double? y;
  final String? selectedObjectId;
  final DateTime updatedAt;

  bool get isCursorEmpty => x == null && y == null;

  Color get color {
    final h = userId.hashCode & 0xFFFFFF;
    return Color(0xFF000000 | h).withValues(alpha: 0.92);
  }

  String get displayLabel {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (userId.length <= 12) return userId;
    return '${userId.substring(0, 10)}…';
  }

  static CollabRemotePointer? fromMessage(Map<String, dynamic> m) {
    final uid = m['fromUserId']?.toString();
    if (uid == null || uid.isEmpty) return null;
    final cur = m['cursor'];
    double? x;
    double? y;
    if (cur is Map) {
      x = (cur['x'] as num?)?.toDouble();
      y = (cur['y'] as num?)?.toDouble();
    }
    final dn = m['displayName'] as String?;
    return CollabRemotePointer(
      userId: uid,
      displayName: dn != null && dn.trim().isEmpty ? null : dn,
      x: x,
      y: y,
      selectedObjectId: m['selectedObjectId'] as String?,
      updatedAt: DateTime.now(),
    );
  }

  static CollabRemotePointer mergeWithPrevious(
    CollabRemotePointer next,
    CollabRemotePointer? previous,
  ) {
    if (previous == null) return next;
    return CollabRemotePointer(
      userId: next.userId,
      displayName: next.displayName ?? previous.displayName,
      x: next.x ?? previous.x,
      y: next.y ?? previous.y,
      selectedObjectId: next.selectedObjectId ?? previous.selectedObjectId,
      updatedAt: next.updatedAt,
    );
  }
}

Set<String> parseHierarchyCollapsedIds(dynamic raw) {
  if (raw is! List) return {};
  return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
}
