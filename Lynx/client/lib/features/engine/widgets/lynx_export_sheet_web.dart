import 'package:flutter/material.dart';

Future<void> showLynxExportSheet(
  BuildContext context, {
  required String projectRoot,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Сборка доступна в десктопном Lynx Launcher')),
  );
}
