class ScriptStudioRemote {
  ScriptStudioRemote({
    required this.userId,
    this.displayName,
    required this.cloudAssetId,
    required this.line,
    required this.column,
    required this.updatedAt,
  });

  final String userId;
  final String? displayName;
  final String cloudAssetId;
  final int line;
  final int column;
  final DateTime updatedAt;

  String get label {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    if (userId.length <= 10) return userId;
    return '${userId.substring(0, 8)}…';
  }

  static ScriptStudioRemote? tryParse(Map<String, dynamic> m) {
    final uid = m['fromUserId']?.toString();
    final aid = m['assetId']?.toString();
    if (uid == null || uid.isEmpty || aid == null || aid.isEmpty) return null;
    return ScriptStudioRemote(
      userId: uid,
      displayName: m['displayName'] as String?,
      cloudAssetId: aid,
      line: (m['line'] as num?)?.toInt() ?? 0,
      column: (m['column'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.now(),
    );
  }
}
