import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/profile_photo_store.dart';
import 'app_dialogs.dart';
import 'app_logout.dart';
import 'sheet_handle.dart';

Future<bool?> showAppSettingsSheet(BuildContext context) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scroll) => _AppSettingsBody(
        scrollController: scroll,
        hostContext: context,
      ),
    ),
  );
}

class _AppSettingsBody extends StatefulWidget {
  const _AppSettingsBody({
    required this.scrollController,
    required this.hostContext,
  });
  final ScrollController scrollController;
  final BuildContext hostContext;
  @override
  State<_AppSettingsBody> createState() => _AppSettingsBodyState();
}

class _AppSettingsBodyState extends State<_AppSettingsBody> {
  bool _photoChanged = false;

  Future<void> _pickHeaderPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty || result.files.single.bytes == null) return;
    await ProfilePhotoStore.saveBytes(result.files.single.bytes!);
    if (mounted) {
      setState(() => _photoChanged = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Фото сохранено')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const SheetGrabHandle(),
          const Text('Настройки', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _tile(PhosphorIconsRegular.image, 'Фото шапки профиля', 'Загрузить своё изображение', _pickHeaderPhoto),
          _tile(PhosphorIconsRegular.trash, 'Убрать фото', null, () async {
            await ProfilePhotoStore.clear();
            if (mounted) setState(() => _photoChanged = true);
          }),
          const Divider(height: 24),
          _tile(PhosphorIconsRegular.info, 'О приложении', null, () => showAboutAppDialog(context)),
          _tile(PhosphorIconsRegular.arrowsClockwise, 'Проверить обновления', null, () => showUpdatesCheckDialog(context)),
          const Divider(height: 24),
          _tile(PhosphorIconsRegular.graduationCap, 'Портал обучения', AppConstants.portalStudyUrl, () async {
            final uri = Uri.parse(AppConstants.portalStudyUrl);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context, _photoChanged);
              showLogoutConfirmDialog(widget.hostContext);
            },
            icon: const Icon(PhosphorIconsRegular.signOut, color: Color(0xFFB91C1C)),
            label: const Text('Выйти', style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), side: const BorderSide(color: Color(0x33B91C1C))),
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final v = snap.data;
              if (v == null) return const SizedBox.shrink();
              return Center(child: Text('v${v.version} (${v.buildNumber})', style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)));
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String? subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(icon, color: AppConstants.blockBlack),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)) : null,
      trailing: Icon(PhosphorIconsRegular.caretRight, size: 18, color: AppConstants.secondaryColor),
      onTap: onTap,
    );
  }
}
