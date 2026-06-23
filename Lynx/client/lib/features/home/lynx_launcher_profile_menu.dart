import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets/lynx_logo.dart';
import '../auth/providers/auth_provider.dart';
import 'lynx_launcher_modular_panels.dart';

Future<void> showLynxLauncherProfileMenu(
  BuildContext context, {
  required RenderBox anchor,
}) {
  return showLynxAccountPanel(context, anchor: anchor);
}

class LynxProfileAvatarButton extends StatelessWidget {
  final GlobalKey avatarKey;
  final VoidCallback onTap;

  const LynxProfileAvatarButton({
    super.key,
    required this.avatarKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final nick = user?.nickname.trim();
    final label = (nick != null && nick.isNotEmpty)
        ? nick.substring(0, 1).toUpperCase()
        : 'L';

    return Material(
      key: avatarKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: _ProfileAvatar(label: label, size: 36),
        ),
      ),
    );
  }
}

class LynxLauncherHubButton extends StatelessWidget {
  final GlobalKey hubKey;
  final VoidCallback onTap;

  const LynxLauncherHubButton({
    super.key,
    required this.hubKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: hubKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.tune_rounded, size: 20, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class LynxBrandMark extends StatelessWidget {
  final double size;

  const LynxBrandMark({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return LynxLogo(size: size, showWordmark: false);
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String label;
  final double size;

  const _ProfileAvatar({required this.label, required this.size});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
