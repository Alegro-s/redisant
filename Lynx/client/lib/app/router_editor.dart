import 'package:flutter/material.dart';

import 'package:client/app/editor_bootstrap.dart';
import 'package:client/app/transitions/app_transitions.dart';
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

GoRouter createEditorRouter(AuthProvider auth) {
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
      final loggedIn = auth.isAuthenticated;
      final onAuthPage =
          path == '/login' || path == '/register' || path == '/verify-email' || path == '/nexus-handoff';
      if (!loggedIn && !onAuthPage) {
        return '/login';
      }
      if (loggedIn && (path == '/login' || path == '/register' || path == '/verify-email')) {
        final boot = EditorBootstrap.instance;
        if (boot.hasProjectContext) {
          return '/engine';
        }
        return '/editor-home';
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
        path: '/editor-home',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const _EditorHomePlaceholder(),
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
        path: '/engine',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final boot = EditorBootstrap.instance;
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: ChangeNotifierProvider(
              create: (_) => SceneProvider(),
              child: EngineMainPage(
                projectId: extra?['projectId'] as String? ?? boot.projectId,
                projectName: extra?['projectName'] as String? ?? boot.projectName,
                projectPath: extra?['projectPath'] as String?,
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
    ],
  );
}

class _EditorHomePlaceholder extends StatelessWidget {
  const _EditorHomePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lynx Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Запустите редактор из Lynx Launcher (кнопка «Редактор» у проекта) '
                'или передайте аргументы:\n'
                '--project-id, --api-base, опционально --cloud-read-only.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/engine-install'),
                icon: const Icon(Icons.download),
                label: const Text('Двоичный движок'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
