import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';

class ShowcaseHeroSlide {
  const ShowcaseHeroSlide({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.colors,
    this.actionUrl,
  });

  final String tag;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final String? actionUrl;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'title': title,
        'subtitle': subtitle,
        'colors': colors.map((c) => c.toARGB32()).toList(),
        if (actionUrl != null) 'actionUrl': actionUrl,
      };

  factory ShowcaseHeroSlide.fromJson(Map<String, dynamic> j) {
    final rawColors = j['colors'] as List<dynamic>? ?? [];
    final colors = rawColors.isEmpty
        ? const [Color(0xFF3A2520), AppConstants.terracottaDark, AppConstants.terracotta]
        : rawColors.map((e) => Color(e as int)).toList();
    return ShowcaseHeroSlide(
      tag: j['tag'] as String? ?? 'Новость',
      title: j['title'] as String? ?? '',
      subtitle: j['subtitle'] as String? ?? '',
      colors: colors,
      actionUrl: j['actionUrl'] as String?,
    );
  }
}

class ShowcaseContentStore {
  ShowcaseContentStore._();

  static const _customSlidesKey = 'showcase_custom_hero_slides';

  static List<ShowcaseHeroSlide> get defaultSlides => const [
        ShowcaseHeroSlide(
          tag: 'Стипендии',
          title: 'Льготы и выплаты',
          subtitle: 'Матпомощь, категории и сроки',
          colors: [Color(0xFF3A2520), AppConstants.terracottaDark, AppConstants.terracotta],
        ),
        ShowcaseHeroSlide(
          tag: 'Университет',
          title: 'ТГПУ рядом с вами',
          subtitle: 'Обучение, расписание, сервисы',
          colors: [AppConstants.blockBlack, AppConstants.blockBlackElevated, Color(0xFF2C2C2C)],
        ),
        ShowcaseHeroSlide(
          tag: 'Карьера',
          title: 'Наука и проекты',
          subtitle: 'Практики, ВКР, мероприятия',
          colors: [Color(0xFF1E2D28), Color(0xFF2A4038), Color(0xFF355A4F)],
        ),
      ];

  static Future<List<ShowcaseHeroSlide>> loadCustomSlides() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_customSlidesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ShowcaseHeroSlide.fromJson(e as Map<String, dynamic>))
          .where((s) => s.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<ShowcaseHeroSlide>> loadEffectiveSlides() async {
    final custom = await loadCustomSlides();
    if (custom.isNotEmpty) return custom;
    return defaultSlides;
  }

  static Future<void> saveCustomSlides(List<ShowcaseHeroSlide> slides) async {
    final p = await SharedPreferences.getInstance();
    if (slides.isEmpty) {
      await p.remove(_customSlidesKey);
      return;
    }
    await p.setString(
      _customSlidesKey,
      jsonEncode(slides.map((s) => s.toJson()).toList()),
    );
  }

  static Future<void> resetToDefaults() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_customSlidesKey);
  }
}
