import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import 'app_logout.dart';
import 'sheet_handle.dart';

Future<void> showAppSettingsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppConstants.surfaceWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              children: [
                const SheetGrabHandle(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppConstants.blockBlack,
                    ),
                  ),
                ),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final v = snapshot.data;
                    return ListTile(
                      leading: const Icon(PhosphorIconsRegular.info, color: AppConstants.blockBlack),
                      title: const Text('О приложении'),
                      subtitle: Text(
                        v == null ? '…' : '${v.version} (${v.buildNumber})',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.arrowsClockwise, color: AppConstants.blockBlack),
                  title: const Text('Проверить обновления'),
                  onTap: () => Navigator.pop(ctx),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.globe, color: AppConstants.blockBlack),
                  title: const Text('Сайт ТГПУ'),
                  subtitle: Text(AppConstants.portalRegisterUrl, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  onTap: () async {
                    final uri = Uri.parse(AppConstants.portalRegisterUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.graduationCap, color: AppConstants.blockBlack),
                  title: const Text('Портал обучения'),
                  subtitle: Text(AppConstants.portalStudyUrl, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  onTap: () async {
                    final uri = Uri.parse(AppConstants.portalStudyUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(PhosphorIconsRegular.signOut, color: Color(0xFFB91C1C)),
                  title: const Text('Выйти из аккаунта', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showLogoutConfirmDialog(context);
                  },
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Закрыть'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
