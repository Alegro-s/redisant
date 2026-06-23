import 'package:dio/dio.dart';

class LynxHubNewsItem {
  final String slug;
  final String title;
  final String date;
  final String body;
  const LynxHubNewsItem({
    required this.slug,
    required this.title,
    required this.date,
    required this.body,
  });

  factory LynxHubNewsItem.fromJson(Map<String, dynamic> j) => LynxHubNewsItem(
    slug: j['slug']?.toString() ?? '',
    title: j['title']?.toString() ?? '',
    date: j['date']?.toString() ?? '',
    body: j['body']?.toString() ?? '',
  );
}

class LynxHubContentService {
  static const defaultHubContentUrl = 'https://lynx.app/content/hub-content.json';

  static Future<List<LynxHubNewsItem>> fetchNews({
    String? contentUrl,
    Dio? dio,
  }) async {
    final url = (contentUrl?.trim().isNotEmpty == true)
        ? contentUrl!.trim()
        : defaultHubContentUrl;
    final client = dio ?? Dio();
    final r = await client.get<dynamic>(
      url,
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final data = r.data;
    if (data is! Map) return const [];
    final raw = data['news'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic> || e is Map)
          LynxHubNewsItem.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }
}
