import 'dart:convert';

import 'package:http/http.dart' as http;

/// Wave 29 — remote config + feature flags for Launcher news / Engine runtime.
class LiveOpsConfigService {
  LiveOpsConfigService({this.configUrl});

  final String? configUrl;
  Map<String, dynamic> _cache = {};
  DateTime? _fetchedAt;

  Map<String, dynamic> get values => Map.unmodifiable(_cache);

  String? string(String key) => _cache[key]?.toString();

  bool flag(String key, {bool defaultValue = false}) {
    final v = _cache[key];
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == '1';
    if (v is num) return v != 0;
    return defaultValue;
  }

  Future<void> refresh({http.Client? client}) async {
    final url = configUrl?.trim();
    if (url == null || url.isEmpty) return;
    final c = client ?? http.Client();
    try {
      final res = await c.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body);
        if (raw is Map) {
          _cache = Map<String, dynamic>.from(raw);
          _fetchedAt = DateTime.now();
        }
      }
    } catch (_) {}
    if (client == null) {
      c.close();
    }
  }

  bool get isStale {
    if (_fetchedAt == null) return true;
    return DateTime.now().difference(_fetchedAt!) > const Duration(minutes: 15);
  }
}
