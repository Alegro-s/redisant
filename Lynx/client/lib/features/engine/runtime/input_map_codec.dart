/// Нормализация `project.json` → `input_map` для Rust.
Map<String, List<String>> normalizeInputMapForEngine(Map<String, dynamic>? raw) {
  if (raw == null || raw.isEmpty) return {};
  final out = <String, List<String>>{};
  for (final e in raw.entries) {
    final v = e.value;
    if (v is List) {
      out[e.key] = v.map((x) => x.toString()).toList();
    } else if (v is String) {
      out[e.key] = [v];
    }
  }
  return out;
}
