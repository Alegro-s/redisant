import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';
import '../../app/themes/nexus_shell_theme.dart';
import '../../app/widgets/lynx_external_links.dart';
import '../auth/providers/auth_provider.dart';

Future<void> showLynxLauncherPanel(
  BuildContext context, {
  required RenderBox anchor,
  required String title,
  required Widget child,
  double width = 320,
}) async {
  final shell = context.nexusShell;
  final offset = anchor.localToGlobal(Offset.zero);

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: anim,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: (offset.dx + 8).clamp(8.0, MediaQuery.of(ctx).size.width - width - 8),
              bottom: MediaQuery.of(ctx).size.height - offset.dy + 8,
              child: SlideTransition(
                position: slide,
                child: Material(
                  elevation: 14,
                  color: shell.sidebar,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: width,
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: shell.sidebarBorder.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, size: 20),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showLynxAccountPanel(
  BuildContext context, {
  required RenderBox anchor,
}) {
  final cs = Theme.of(context).colorScheme;

  return showLynxLauncherPanel(
    context,
    anchor: anchor,
    title: 'Аккаунт',
    child: LynxAccountPanelBody(
      onProjects: () {
        Navigator.pop(context);
        context.go('/?module=projects');
      },
      onProfile: () {
        Navigator.pop(context);
        context.push('/profile');
      },
      onLogin: () {
        Navigator.pop(context);
        context.push('/login');
      },
      onLogout: () async {
        Navigator.pop(context);
        await context.read<AuthProvider>().logout();
      },
      onLegal: (tab) {
        Navigator.pop(context);
        openLynxLegal(context, tab: tab);
      },
      dense: true,
      leadingColor: cs.primary,
    ),
  );
}

class LynxAccountPanelBody extends StatelessWidget {
  const LynxAccountPanelBody({
    super.key,
    required this.onProjects,
    this.onProfile,
    this.onLogin,
    this.onLogout,
    this.onLegal,
    this.dense = false,
    this.leadingColor,
  });

  final VoidCallback onProjects;
  final VoidCallback? onProfile;
  final VoidCallback? onLogin;
  final Future<void> Function()? onLogout;
  final void Function(String tab)? onLegal;
  final bool dense;
  final Color? leadingColor;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final cs = Theme.of(context).colorScheme;
    final iconColor = leadingColor ?? cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (user != null) ...[
          if (!dense) ...[
            _panelTile(
              icon: Icons.alternate_email_rounded,
              label: 'Никнейм',
              subtitle: '@${user.nickname}',
            ),
            _panelTile(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              subtitle: user.email,
            ),
          ] else ...[
            ListTile(
              dense: true,
              leading: const Icon(Icons.alternate_email_rounded),
              title: Text('@${user.nickname}'),
              subtitle: Text(user.email),
            ),
          ],
          ListTile(
            dense: dense,
            leading: Icon(Icons.folder_open_outlined, color: iconColor),
            title: const Text('Мои проекты'),
            trailing: dense ? const Icon(Icons.chevron_right, size: 18) : null,
            onTap: onProjects,
          ),
          if (onProfile != null)
            ListTile(
              dense: dense,
              leading: Icon(Icons.manage_accounts_outlined, color: iconColor),
              title: const Text('Управление аккаунтом'),
              trailing: dense ? const Icon(Icons.chevron_right, size: 18) : null,
              onTap: onProfile,
            ),
        ] else
          ListTile(
            dense: dense,
            leading: Icon(Icons.login_rounded, color: iconColor),
            title: const Text('Войти'),
            onTap: onLogin,
          ),
        const Divider(height: 20),
        Text(
          'Юридическая информация',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        if (onLegal != null) ...[
          _panelAction(
            context,
            icon: Icons.privacy_tip_outlined,
            label: 'Политика конфиденциальности',
            onTap: () => onLegal!('privacy'),
          ),
          _panelAction(
            context,
            icon: Icons.article_outlined,
            label: 'Условия использования',
            onTap: () => onLegal!('terms'),
          ),
        ],
        if (auth.isAuthenticated && onLogout != null) ...[
          const SizedBox(height: 8),
          _panelAction(
            context,
            icon: Icons.logout_rounded,
            label: 'Выйти',
            destructive: true,
            onTap: () => onLogout!(),
          ),
        ],
      ],
    );
  }
}

Future<void> showLynxSettingsPanel(
  BuildContext context, {
  required RenderBox anchor,
}) {
  return showLynxLauncherPanel(
    context,
    anchor: anchor,
    title: 'Настройки',
    width: 340,
    child: const LynxSettingsPanelBody(),
  );
}

class LynxSettingsPanelBody extends StatelessWidget {
  const LynxSettingsPanelBody();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Конфиденциальность',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        _panelAction(
          context,
          icon: Icons.privacy_tip_outlined,
          label: 'Политика конфиденциальности',
          onTap: () {
            Navigator.pop(context);
            openLynxLegal(context, tab: 'privacy');
          },
        ),
        const Divider(height: 16),
        Text(
          'Доступы',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        _panelAction(
          context,
          icon: Icons.vpn_key_outlined,
          label: 'Доступ к продуктам',
          onTap: () {
            Navigator.pop(context);
            context.push('/profile');
          },
        ),
        _panelAction(
          context,
          icon: Icons.dns_outlined,
          label: 'Сервер Lynx',
          onTap: () {
            Navigator.pop(context);
            context.push('/profile');
          },
        ),
        const Divider(height: 16),
        Text(
          'Модули навигации',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        ...availableModules.map((m) {
          final id = m['id']?.toString() ?? '';
          return SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            secondary: Icon(
              m['icon'] is IconData ? m['icon'] as IconData : Icons.widgets_outlined,
              size: 22,
              color: cs.onSurfaceVariant,
            ),
            title: Text(m['title']?.toString() ?? id, style: const TextStyle(fontSize: 14)),
            value: settings.enabledModules.contains(id),
            onChanged: id == 'home' ? null : (v) => settings.toggleModule(id, v),
          );
        }),
      ],
    );
  }
}

Future<void> showLynxCustomizationPanel(
  BuildContext context, {
  required RenderBox anchor,
}) {
  return showLynxLauncherPanel(
    context,
    anchor: anchor,
    title: 'Кастомизация',
    child: const LynxCustomizationPanelBody(),
  );
}

class LynxCustomizationPanelBody extends StatelessWidget {
  const LynxCustomizationPanelBody();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Тема оформления',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _themeOption(
          context,
          settings: settings,
          theme: AppTheme.purple,
          title: 'Lynx Purple',
          subtitle: 'Фиолетовая — для главной и Hub',
          swatch: const Color(0xFFC084FC),
        ),
        const SizedBox(height: 8),
        _themeOption(
          context,
          settings: settings,
          theme: AppTheme.midnight,
          title: 'Тёмная',
          subtitle: 'Тёмно-серая · серая · белая',
          swatch: const Color(0xFF71717A),
        ),
        const SizedBox(height: 8),
        _themeOption(
          context,
          settings: settings,
          theme: AppTheme.monochrome,
          title: 'Светлая',
          subtitle: 'Белая · тёмно-серая',
          swatch: const Color(0xFF18181B),
        ),
      ],
    );
  }
}

Future<void> showLynxModulesReorderPanel(
  BuildContext context, {
  required RenderBox anchor,
}) {
  return showLynxLauncherPanel(
    context,
    anchor: anchor,
    title: 'Модули лаунчера',
    width: 340,
    child: const LynxModulesReorderBody(),
  );
}

Future<void> showLynxAccountSheet(BuildContext context) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return context.push('/launcher-account');
  }
  final shell = context.nexusShell;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: shell.sidebar,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('Аккаунт', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: LynxAccountPanelBody(
                  onProjects: () {
                    Navigator.pop(context);
                    context.go('/?module=projects');
                  },
                  onProfile: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                  onLogin: () {
                    Navigator.pop(context);
                    context.push('/login');
                  },
                  onLogout: () async {
                    Navigator.pop(context);
                    await context.read<AuthProvider>().logout();
                  },
                  onLegal: (tab) {
                    Navigator.pop(context);
                    openLynxLegal(context, tab: tab);
                  },
                  dense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showLynxLauncherHubSheet(BuildContext context) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return context.push('/launcher-settings');
  }
  final shell = context.nexusShell;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: shell.sidebar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Настройки'),
            onTap: () {
              Navigator.pop(ctx);
              showLynxSettingsSheet(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Кастомизация'),
            onTap: () {
              Navigator.pop(ctx);
              showLynxCustomizationSheet(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drag_indicator_rounded),
            title: const Text('Модули лаунчера'),
            onTap: () {
              Navigator.pop(ctx);
              showLynxModulesSheet(context);
            },
          ),
        ],
      ),
    ),
  );
}

void showLynxSettingsSheet(BuildContext context) {
  if (MediaQuery.sizeOf(context).width < 600) {
    context.push('/launcher-settings');
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.nexusShell.sidebar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.65,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Настройки', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const LynxSettingsPanelBody(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showLynxCustomizationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.nexusShell.sidebar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text('Кастомизация', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            SizedBox(height: 12),
            LynxCustomizationPanelBody(),
          ],
        ),
      ),
    ),
  );
}

void showLynxModulesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.nexusShell.sidebar,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.55,
        child: Column(
          children: const [
            Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Модули лаунчера', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ),
            ),
            Expanded(child: LynxModulesReorderBody()),
          ],
        ),
      ),
    ),
  );
}

Future<void> showLynxLauncherHubMenu(
  BuildContext context, {
  required RenderBox anchor,
}) {
  final cs = Theme.of(context).colorScheme;
  return showLynxLauncherPanel(
    context,
    anchor: anchor,
    title: 'Управление',
    width: 280,
    child: Column(
      children: [
        _panelAction(
          context,
          icon: Icons.settings_outlined,
          label: 'Настройки',
          onTap: () {
            Navigator.pop(context);
            showLynxSettingsPanel(context, anchor: anchor);
          },
        ),
        _panelAction(
          context,
          icon: Icons.palette_outlined,
          label: 'Кастомизация',
          onTap: () {
            Navigator.pop(context);
            showLynxCustomizationPanel(context, anchor: anchor);
          },
        ),
        _panelAction(
          context,
          icon: Icons.drag_indicator_rounded,
          label: 'Модули лаунчера',
          onTap: () {
            Navigator.pop(context);
            showLynxModulesReorderPanel(context, anchor: anchor);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Text(
            'Перетащите модули в списке ниже или откройте «Модули лаунчера».',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class LynxModulesReorderBody extends StatefulWidget {
  const LynxModulesReorderBody();

  @override
  State<LynxModulesReorderBody> createState() => _LynxModulesReorderBodyState();
}

class _LynxModulesReorderBodyState extends State<LynxModulesReorderBody> {
  late List<Map<String, dynamic>> _modules;

  @override
  void initState() {
    super.initState();
    _modules = context.read<SettingsProvider>().getVisibleModulesInOrder();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final shell = context.nexusShell;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _modules.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (oldIndex < newIndex) newIndex -= 1;
          final item = _modules.removeAt(oldIndex);
          _modules.insert(newIndex, item);
        });
        final order = _modules
            .map((m) => m['id']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        settings.updateModulesOrder(order);
      },
      itemBuilder: (ctx, i) {
        final m = _modules[i];
        final id = m['id']?.toString() ?? 'mod_$i';
        return Material(
          key: ValueKey(id),
          color: shell.sidebarHover.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            dense: true,
            leading: Icon(
              m['icon'] is IconData ? m['icon'] as IconData : Icons.widgets_outlined,
              size: 20,
            ),
            title: Text(m['title']?.toString() ?? id, style: const TextStyle(fontSize: 14)),
            trailing: ReorderableDragStartListener(
              index: i,
              child: const Icon(Icons.drag_handle_rounded, size: 20),
            ),
          ),
        );
      },
    );
  }
}

Widget _themeOption(
  BuildContext context, {
  required SettingsProvider settings,
  required AppTheme theme,
  required String title,
  required String subtitle,
  required Color swatch,
}) {
  final selected = settings.currentTheme == theme;
  final cs = Theme.of(context).colorScheme;
  return Material(
    color: selected ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHigh.withValues(alpha: 0.35),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => settings.setTheme(theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: cs.primary, size: 20),
          ],
        ),
      ),
    ),
  );
}

Widget _panelTile({
  required IconData icon,
  required String label,
  required String subtitle,
}) {
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon, size: 22),
    title: Text(label, style: const TextStyle(fontSize: 13)),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
  );
}

Widget _panelAction(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool destructive = false,
}) {
  final cs = Theme.of(context).colorScheme;
  return ListTile(
    dense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon, size: 22, color: destructive ? cs.error : cs.onSurfaceVariant),
    title: Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: destructive ? cs.error : null,
      ),
    ),
    onTap: onTap,
  );
}
