import 'package:flutter/services.dart';

class AndroidEngineIntent {
  static const _ch = MethodChannel('lynx/engine_launcher');

  static Future<Map<String, dynamic>> read() async {
    try {
      final raw = await _ch.invokeMethod<Map>('readIntentExtras');
      if (raw == null) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return {};
    }
  }
}
