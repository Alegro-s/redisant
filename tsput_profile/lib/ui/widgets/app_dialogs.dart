import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants.dart';
import '../../data/services/api_service.dart';

Future<void> showAboutAppDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('О приложении', style: TextStyle(fontWeight: FontWeight.w800)),
      content: const SingleChildScrollView(
        child: Text(
          '«ТОЛСТОВСКИЙ PROFILE» — волонтёрский проект для Тульского '
          'государственного педагогического университета имени Льва Николаевича Толстого.\n\n'
          'Приложение упрощает жизнь студентов: расписание, успеваемость, портфолио, '
          'сервисы университета и уведомления с портала обучения.',
          style: TextStyle(height: 1.45, fontSize: 14),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          style: FilledButton.styleFrom(backgroundColor: AppConstants.blockBlack),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}

Future<void> showUpdatesCheckDialog(BuildContext context) async {
  final local = await PackageInfo.fromPlatform();
  Map<String, dynamic>? remote;
  try {
    remote = await ApiService().fetchAppRelease();
  } catch (_) {}

  if (!context.mounted) return;

  final remoteVer = remote?['version']?.toString() ?? AppConstants.appVersion;
  final remoteBuild = remote?['buildNumber']?.toString() ?? AppConstants.appBuild;
  final hasUpdate = remoteVer != local.version || remoteBuild != local.buildNumber;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(hasUpdate ? 'Доступно обновление' : 'Обновления', style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        hasUpdate
            ? 'В облаке: $remoteVer ($remoteBuild). У вас: ${local.version} (${local.buildNumber}).'
            : 'Сейчас актуальная версия: ${local.version} (${local.buildNumber}).',
        style: const TextStyle(height: 1.45, fontSize: 14),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
      ],
    ),
  );
}
