import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:client/app/engine_bootstrap.dart';
import 'package:client/app/transitions/app_transitions.dart';
import 'package:client/features/engine/providers/engine_workspace_provider.dart';
import 'package:client/features/engine/providers/scene_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/nexus_handoff_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/engine/screens/engine_main_page.dart';
import '../features/game/game_player_screen.dart';
import '../features/engine/screens/engine_install_hub_screen.dart';
import '../features/game/cart_play_screen.dart';

GoRouter createEngineRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      const publicPaths = {'/login', '/register', '/nexus-handoff'};
      if (!auth.bootstrapped) {
        if (!publicPaths.contains(path)) {
          return '/login';
        }
        return null;
      }
      if (path == '/workspace' || path == '/engine-home') {
        final boot = EngineBootstrap.instance;
        if (boot.hasProjectContext) return '/workspace';
      }
      final loggedIn = auth.isAuthenticated;
      final onAuthPage =
          path == '/login' || path == '/register' || path == '/verify-email' || path == '/nexus-handoff';
      if (!loggedIn && !onAuthPage) {
        final boot = EngineBootstrap.instance;
        if (boot.hasProjectContext && (path == '/workspace' || path == '/login')) {
          return '/workspace';
        }
        return '/login';
      }
      if (loggedIn && (path == '/login' || path == '/register' || path == '/verify-email')) {
        final boot = EngineBootstrap.instance;
        if (boot.playOnly && boot.hasCartContext) {
          return '/play-cart';
        }
        if (boot.hasProjectContext) {
          return '/workspace';
        }
        return '/engine-home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: VerifyEmailScreen(initialEmail: email),
          );
        },
      ),
      GoRoute(
        path: '/nexus-handoff',
        pageBuilder: (context, state) {
          final q = state.uri.queryParameters;
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: NexusHandoffScreen(
              challengeId: q['challenge_id'] ?? '',
              sessionToken: q['session_token'] ?? '',
              apiBase: q['api_base'],
            ),
          );
        },
      ),
      GoRoute(
        path: '/engine-home',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const _EngineHomePlaceholder(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/engine-install',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const EngineInstallHubScreen(),
        ),
      ),
      GoRoute(
        path: '/workspace',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final boot = EngineBootstrap.instance;
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => SceneProvider()),
                ChangeNotifierProvider(create: (_) => EngineWorkspaceProvider()),
              ],
              child: EngineMainPage(
                projectId: extra?['projectId'] as String? ?? boot.projectId,
                projectName: extra?['projectName'] as String? ?? boot.projectName,
                projectPath: extra?['projectPath'] as String? ?? boot.projectPath,
                cloudReadOnly: extra?['cloudReadOnly'] == true || boot.cloudReadOnly,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/play',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: GamePlayerScreen(
              projectPath: extra?['projectPath'] as String?,
              freshPlay: extra?['freshPlay'] == true,
            ),
          );
        },
      ),
      GoRoute(
        path: '/play-cart',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final boot = EngineBootstrap.instance;
          final cartId = state.uri.queryParameters['cartId'];
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: CartPlayScreen(
              cartPath: extra?['cartPath'] as String? ?? boot.cartPath,
              cartId: cartId,
            ),
          );
        },
      ),
    ],
  );
}

class _EngineHomePlaceholder extends StatelessWidget {
  const _EngineHomePlaceholder();

  static const _cloudCabinetUrl = 'https://lynx-cloud.ru/cabinet/projects';

  Future<void> _openCloudCabinet() async {
    final uri = Uri.parse(_cloudCabinetUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lynx Engine')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Редактор в браузере',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Облачные проекты хранятся на сервере Lynx Cloud. '
                  'Откройте проект в кабинете — редактор подтянет сцены и ассеты по API. '
                  'Ссылка вида: /engine-web/?project=cloud:<id>',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/workspace'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Открыть редактор'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _openCloudCabinet,
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Проекты в Lynx Cloud'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lynx Engine')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Запустите Lynx Engine из Launcher (кнопка «Работать») '
                'или передайте --project-path / --project-id и --engine-ver.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/engine-install'),
                icon: const Icon(Icons.download),
                label: const Text('Установить ядро'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
