import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'engine_binary_loader.dart';

Future<bool> ensureStudioEngineForLocalProject(
  BuildContext context,
  Dio dio, {
  bool forceCheck = false,
}) async {
  if (!context.mounted) return false;
  final existing = await getLastCachedEngineLibraryPath();
  if (existing != null && !forceCheck) {
    return true;
  }

  if (!context.mounted) return false;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Ядро NEXUS'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Скачивается нативная библиотека Rust (аналог установки модулей движка). '
              'Без неё предпросмотр и Play не работают на ПК.',
            ),
            SizedBox(height: 16),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    ),
  );

  String? err;
  try {
    final path = await ensureEngineBinary(dio);
    if (path != null) {
      if (context.mounted) nav.pop();
      return true;
    }
    err = 'Сервер не вернул ядро для вашей системы. Проверьте интернет и войдите в аккаунт Lynx.';
  } catch (e) {
    err = e.toString();
  }

  if (context.mounted) nav.pop();
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Ядро не установлено'),
      content: Text(
        err ??
            'Откройте «Центр ядра» в списке проектов и установите ядро. Нужен вход в Lynx и доступ в интернет.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
      ],
    ),
  );
  return false;
}
