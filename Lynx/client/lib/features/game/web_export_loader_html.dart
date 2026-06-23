import 'dart:async';
import 'dart:html' as html;

/// Загрузка `web/game_data/` после `flutter build web` (волна 3).
Future<String?> fetchWebGameDataText(String relativePath) async {
  final base = Uri.base.resolve('game_data/');
  final url = base.resolve(relativePath.replaceAll('\\', '/')).toString();
  try {
    final req = await html.HttpRequest.request(
      url,
      method: 'GET',
      responseType: 'text',
    );
    if (req.status != null && req.status! >= 400) return null;
    return req.responseText;
  } catch (_) {
    return null;
  }
}
