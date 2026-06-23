import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/widgets/lynx_external_links.dart';
import '../auth/providers/auth_provider.dart';
import 'lynx_launcher_modular_panels.dart';

class LynxLauncherSettingsPage extends StatelessWidget {
  const LynxLauncherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          const LynxSettingsPanelBody(),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Кастомизация'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/launcher-customization'),
          ),
          ListTile(
            leading: const Icon(Icons.drag_indicator_outlined),
            title: const Text('Модули лаунчера'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/launcher-modules'),
          ),
        ],
      ),
    );
  }
}

class LynxLauncherCustomizationPage extends StatelessWidget {
  const LynxLauncherCustomizationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кастомизация'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: LynxCustomizationPanelBody(),
      ),
    );
  }
}

class LynxLauncherModulesPage extends StatelessWidget {
  const LynxLauncherModulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Модули лаунчера'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(12),
        child: LynxModulesReorderBody(),
      ),
    );
  }
}

class LynxLauncherAccountPage extends StatelessWidget {
  const LynxLauncherAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аккаунт'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        children: [
          LynxAccountPanelBody(
            onProjects: () => context.go('/?module=projects'),
            onProfile: () => context.push('/profile'),
            onLogin: () => context.push('/login'),
            onLogout: () => context.read<AuthProvider>().logout(),
            onLegal: (tab) => openLynxLegal(context, tab: tab),
          ),
        ],
      ),
    );
  }
}

bool lynxUseMobileLauncherPages(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;

void openLynxLauncherSettings(BuildContext context) {
  if (lynxUseMobileLauncherPages(context)) {
    context.push('/launcher-settings');
  } else {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      showLynxSettingsPanel(context, anchor: box);
    }
  }
}

void openLynxLauncherAccount(BuildContext context) {
  if (lynxUseMobileLauncherPages(context)) {
    context.push('/launcher-account');
  } else {
    final box = context.findRenderObject();
    if (box is RenderBox) {
      showLynxAccountPanel(context, anchor: box);
    }
  }
}
