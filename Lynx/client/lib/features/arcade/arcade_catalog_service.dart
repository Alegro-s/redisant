import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'arcade_api_service.dart';

class ArcadeGameEntry {
  ArcadeGameEntry({
    required this.id,
    required this.title,
    required this.description,
    this.tags = const [],
    this.tier = 'free_to_play',
    this.cartUrl,
    this.thumbnailUrl,
    this.projectTemplate,
  });

  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final String tier;
  final String? cartUrl;
  final String? thumbnailUrl;
  final String? projectTemplate;

  factory ArcadeGameEntry.fromJson(Map<String, dynamic> json) {
    return ArcadeGameEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Игра',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      tier: json['tier'] as String? ?? 'free_to_play',
      cartUrl: json['cartUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      projectTemplate: json['projectTemplate'] as String?,
    );
  }
}

/// Каталог Cloud Arcade (L18 / Hub API).
class ArcadeCatalogService {
  ArcadeCatalogService({Dio? dio}) : _dio = dio;

  final Dio? _dio;

  static const defaultCatalogUrl =
      'https://lynx-hub.ru/content/marketplace-catalog.json';

  Future<List<ArcadeGameEntry>> loadFreeToPlay({String? catalogUrl, String? apiBase}) async {
    if (_dio != null) {
      try {
        final api = ArcadeApiService(_dio!, baseUrl: apiBase);
        final items = await api.fetchCatalog();
        if (items.isNotEmpty) return items;
      } catch (e) {
        debugPrint('ArcadeCatalogService API: $e');
      }
    }

    final url = catalogUrl?.trim().isNotEmpty == true
        ? catalogUrl!.trim()
        : defaultCatalogUrl;
    try {
      final client = _dio ?? Dio();
      final res = await client.get<String>(url);
      final data = jsonDecode(res.data ?? '[]');
      final List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        return _builtinFallback();
      }
      return items
          .map((e) => ArcadeGameEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((g) => g.tier == 'free_to_play' || g.tags.contains('arcade'))
          .toList();
    } catch (e) {
      debugPrint('ArcadeCatalogService: $e');
      return _builtinFallback();
    }
  }

  List<ArcadeGameEntry> _builtinFallback() {
    return [
      ArcadeGameEntry(
        id: 'lynx-tetris',
        title: 'Lynx Tetris',
        description: 'Классический тетрис на logic grid.',
        tags: const ['puzzle', 'arcade', 'tetris'],
        tier: 'free_to_play',
        projectTemplate: 'lynx-tetris',
      ),
      ArcadeGameEntry(
        id: 'game-tetris-demo',
        title: 'Tetris Demo',
        description: 'Демо tetris-demo из шаблонов Lynx.',
        tags: const ['puzzle', 'arcade'],
        tier: 'free_to_play',
        projectTemplate: 'tetris-demo',
      ),
    ];
  }
}
