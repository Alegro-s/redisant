import 'dart:convert';

import 'package:http/http.dart' as http;

/// Wave 29 — leaderboard stub (cloud API contract).
class LiveOpsLeaderboardEntry {
  final String playerId;
  final String displayName;
  final int score;
  final int rank;

  const LiveOpsLeaderboardEntry({
    required this.playerId,
    required this.displayName,
    required this.score,
    required this.rank,
  });

  factory LiveOpsLeaderboardEntry.fromJson(Map<String, dynamic> j) => LiveOpsLeaderboardEntry(
        playerId: j['player_id'] as String? ?? '',
        displayName: j['display_name'] as String? ?? 'Player',
        score: (j['score'] as num?)?.toInt() ?? 0,
        rank: (j['rank'] as num?)?.toInt() ?? 0,
      );
}

class LiveOpsLeaderboardService {
  LiveOpsLeaderboardService({this.apiBase});

  final String? apiBase;

  Future<List<LiveOpsLeaderboardEntry>> fetchTop({String boardId = 'default', int limit = 20}) async {
    final base = apiBase?.trim();
    if (base == null || base.isEmpty) {
      return List.generate(
        5,
        (i) => LiveOpsLeaderboardEntry(
          playerId: 'demo_$i',
          displayName: 'Player ${i + 1}',
          score: 1000 - i * 120,
          rank: i + 1,
        ),
      );
    }
    try {
      final uri = Uri.parse('$base/leaderboards/$boardId?limit=$limit');
      final res = await http.get(uri);
      if (res.statusCode != 200) return const [];
      final raw = jsonDecode(res.body);
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => LiveOpsLeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> submitScore({
    required String boardId,
    required String playerId,
    required int score,
    String? authToken,
  }) async {
    final base = apiBase?.trim();
    if (base == null || base.isEmpty) return true;
    try {
      final uri = Uri.parse('$base/leaderboards/$boardId/scores');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'player_id': playerId, 'score': score}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
