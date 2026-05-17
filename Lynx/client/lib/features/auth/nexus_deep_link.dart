import 'package:go_router/go_router.dart';

bool isNexusAuthDeepLink(Uri uri) {
  return uri.scheme == 'nexus' && uri.host == 'nexus-auth';
}

void openNexusAuthHandoff(GoRouter router, Uri uri) {
  if (!isNexusAuthDeepLink(uri)) return;
  final p = uri.queryParameters;
  if ((p['challenge_id'] ?? '').isEmpty || (p['session_token'] ?? '').isEmpty) {
    return;
  }
  final loc = Uri(path: '/nexus-handoff', queryParameters: p).toString();
  router.push(loc);
}
