import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../lynx_urls.dart';

Future<void> openLynxDocs(BuildContext context) async {
  await _openExternal(context, LynxUrls.docs, fallbackRoute: null);
}

Future<void> openLynxLegal(
  BuildContext context, {
  required String tab,
}) async {
  final url = tab == 'terms' ? LynxUrls.terms : LynxUrls.privacy;
  await _openExternal(context, url, fallbackRoute: '/legal?tab=$tab');
}

Future<void> _openExternal(
  BuildContext context,
  String url, {
  String? fallbackRoute,
}) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {}
  if (!context.mounted || fallbackRoute == null) return;
  context.push(fallbackRoute);
}
