import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePhotoStore {
  ProfilePhotoStore._();

  static const _key = 'profile_header_photo_base64';

  static Future<Uint8List?> loadBytes() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveBytes(Uint8List bytes) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, base64Encode(bytes));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
