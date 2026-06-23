import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

class AppAppearance {
  AppAppearance._();

  static const _headerPresetKey = 'profile_header_preset';
  static const _promoTitleKey = 'profile_promo_title';
  static const _promoSubtitleKey = 'profile_promo_subtitle';

  static Future<ProfileHeaderPreset> headerPreset() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_headerPresetKey) ?? ProfileHeaderPreset.standard.name;
    return ProfileHeaderPreset.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => ProfileHeaderPreset.standard,
    );
  }

  static Future<void> setHeaderPreset(ProfileHeaderPreset preset) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_headerPresetKey, preset.name);
  }

  static Future<({String title, String subtitle})> promoTexts() async {
    final p = await SharedPreferences.getInstance();
    return (
      title: p.getString(_promoTitleKey) ?? 'Стипендии и сервисы',
      subtitle: p.getString(_promoSubtitleKey) ??
          'Новости университета, льготы и документы на портале',
    );
  }

  static Future<void> setPromoTexts({String? title, String? subtitle}) async {
    final p = await SharedPreferences.getInstance();
    if (title != null) await p.setString(_promoTitleKey, title);
    if (subtitle != null) await p.setString(_promoSubtitleKey, subtitle);
  }

  static Future<void> resetToDefaults() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_headerPresetKey);
    await p.remove(_promoTitleKey);
    await p.remove(_promoSubtitleKey);
  }

  static List<Color> headerGradient(ProfileHeaderPreset preset) {
    switch (preset) {
      case ProfileHeaderPreset.standard:
        return const [
          AppConstants.blockBlack,
          AppConstants.blockBlackElevated,
          Color(0xFF2C2C2C),
        ];
      case ProfileHeaderPreset.terracotta:
        return const [
          Color(0xFF3A2520),
          AppConstants.terracottaDark,
          AppConstants.terracotta,
        ];
      case ProfileHeaderPreset.forest:
        return const [
          Color(0xFF1E2D28),
          Color(0xFF2A4038),
          Color(0xFF355A4F),
        ];
      case ProfileHeaderPreset.slate:
        return const [
          Color(0xFF1A2332),
          Color(0xFF2A3548),
          Color(0xFF3D4F66),
        ];
    }
  }
}

enum ProfileHeaderPreset {
  standard('Как сейчас'),
  terracotta('Терракота'),
  forest('Зелёный'),
  slate('Сланцевый');

  const ProfileHeaderPreset(this.label);
  final String label;
}
