import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/providers/auth_provider.dart';
import '../engine/project_manager.dart';
import 'lynx_cloud_urls.dart';

/// Открыть облачный проект в Web Engine (Launcher или браузер).
Future<void> openCloudProjectInBrowser(
  BuildContext context, {
  required String projectId,
  String? projectName,
  bool readOnly = false,
}) async {
  if (kIsWeb) {
    context.push(
      LynxCloudUrls.engineWebRoute(
        projectId: projectId,
        projectName: projectName,
        readOnly: readOnly,
      ),
    );
    return;
  }
  final auth = context.read<AuthProvider>();
  final hub = auth.dioBaseUrl.contains('localhost') || auth.dioBaseUrl.contains('127.0.0.1')
      ? auth.dioBaseUrl.replaceAll(RegExp(r'/api.*$'), '')
      : LynxCloudUrls.hubOrigin;
  final url = LynxCloudUrls.engineWeb(
    projectId: projectId,
    projectName: projectName,
    hubBase: hub,
    readOnly: readOnly,
  );
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть $url')),
    );
  }
}

/// Диалог разрешения конфликта синхронизации сцены (HTTP 409).
Future<LynxCloudConflictAction?> showLynxCloudConflictDialog(
  BuildContext context, {
  required String message,
  required bool readOnly,
}) {
  return showDialog<LynxCloudConflictAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Конфликт синхронизации'),
      content: Text(
        '$message\n\n'
        '${readOnly ? 'Загрузите актуальную версию с сервера.' : 'Можно сохранить локальную копию и перезагрузить проект с сервера.'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, LynxCloudConflictAction.dismiss),
          child: const Text('Позже'),
        ),
        if (!readOnly)
          TextButton(
            onPressed: () => Navigator.pop(ctx, LynxCloudConflictAction.backupAndReload),
            child: const Text('Копия + перезагрузка'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, LynxCloudConflictAction.reloadFromServer),
          child: const Text('С сервера'),
        ),
      ],
    ),
  );
}

enum LynxCloudConflictAction { dismiss, reloadFromServer, backupAndReload }

Future<void> handleLynxCloudConflictAction(
  BuildContext context,
  ProjectManager manager,
  LynxCloudConflictAction action,
) async {
  if (action == LynxCloudConflictAction.dismiss) return;

  if (action == LynxCloudConflictAction.backupAndReload) {
    final backup = await manager.exportCloudProjectBackup();
    if (context.mounted && backup != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Локальная копия: $backup')),
      );
    }
  }

  final err = await manager.reloadCloudProjectFromServer();
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err), backgroundColor: Colors.deepOrange),
    );
  } else {
    manager.clearCloudSyncConflict();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Проект перезагружен с сервера')),
    );
  }
}

/// Баннер конфликта облачной синхронизации.
class LynxCloudSyncBanner extends StatelessWidget {
  const LynxCloudSyncBanner({
    super.key,
    required this.message,
    required this.readOnly,
    required this.onResolve,
  });

  final String message;
  final bool readOnly;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.sync_problem_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: onResolve,
              child: const Text('Разрешить'),
            ),
          ],
        ),
      ),
    );
  }
}
