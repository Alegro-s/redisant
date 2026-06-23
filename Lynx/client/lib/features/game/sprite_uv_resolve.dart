/// Разрешение UV спрайта: приоритет у кадра из ядра (`uv_rect`), fallback — локальный таймлайн.
Map<String, dynamic>? resolveSpriteUvRect({
  required Map<String, dynamic>? engineUv,
  required Map<String, dynamic>? sprite,
  required double elapsedSeconds,
}) {
  if (_isValidUv(engineUv)) {
    return Map<String, dynamic>.from(engineUv!);
  }
  final anim = sprite?['animation'] as Map<String, dynamic>?;
  final frames = anim?['frames'] as List<dynamic>?;
  if (frames == null || frames.isEmpty) {
    return _isValidUv(engineUv) ? Map<String, dynamic>.from(engineUv!) : null;
  }
  final fps = (anim?['fps'] as num?)?.toDouble() ?? 8;
  final fi = (elapsedSeconds * fps).floor() % frames.length;
  return Map<String, dynamic>.from(frames[fi] as Map);
}

bool _isValidUv(Map<String, dynamic>? uv) {
  if (uv == null) return false;
  final w = (uv['w'] as num?)?.toDouble() ?? 0;
  final h = (uv['h'] as num?)?.toDouble() ?? 0;
  return w > 0 && h > 0;
}

/// Единый ключ кэша текстур (пути из проекта).
String normalizeTextureCacheKey(String rel) {
  return rel.replaceAll('\\', '/');
}
