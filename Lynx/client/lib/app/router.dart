import 'package:client/app/transitions/app_transitions.dart';
import 'package:client/features/engine/providers/scene_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/verify_email_screen.dart';
import '../features/auth/screens/nexus_handoff_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/engine/screens/engine_main_page.dart';
import '../features/game/game_player_screen.dart';
import '../features/projects/screens/project_detail_screen.dart';
import '../features/projects/screens/projects_screen.dart';
import '../features/engine/screens/engine_install_hub_screen.dart';
import '../features/legal/legal_notice_screen.dart';
import '../features/settings/launcher_dev_settings_screen.dart';

GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final path = state.uri.path;
      const publicPaths = {'/login', '/register', '/nexus-handoff', '/legal'};
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
        return '/';
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
        path: '/legal',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'] ?? 'privacy';
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: LegalNoticeScreen(initialTab: tab),
          );
        },
      ),
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const HomeScreen(),
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
        path: '/project/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: ProjectDetailScreen(projectId: id),
          );
        },
      ),
      GoRoute(
        path: '/projects',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Проекты'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
            body: const ProjectsScreen(),
          ),
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
        path: '/launcher-dev-settings',
        pageBuilder: (context, state) => nexusFadeSlidePage(
          key: state.pageKey,
          child: const LauncherDevSettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/engine',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return nexusFadeSlidePage(
            key: state.pageKey,
            child: ChangeNotifierProvider(
              create: (_) => SceneProvider(),
              child: EngineMainPage(
                projectId: extra?['projectId'] as String?,
                projectName: extra?['projectName'] as String?,
                projectPath: extra?['projectPath'] as String?,
                cloudReadOnly: extra?['cloudReadOnly'] == true,
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
