import 'package:app_links/app_links.dart';
import 'package:client/app/engine_bootstrap.dart';
import 'package:client/app/providers/settings_provider.dart';
import 'package:client/app/router_engine.dart';
import 'package:client/features/auth/nexus_deep_link.dart';
import 'package:client/features/auth/providers/auth_provider.dart';
import 'package:client/features/engine/project_manager.dart';
import 'package:client/features/plugins/lynx_plugin_registry.dart';
import 'package:client/features/projects/providers/project_provider.dart';
import 'package:client/features/assets/providers/asset_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Lynx Engine — единый shell: редактор + Play + сборка (волна 16).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LynxPluginRegistry.instance.ensureInitialized();
  await EngineBootstrap.ensureInitialized();
  final auth = AuthProvider();
  final boot = EngineBootstrap.instance;
  if (boot.apiBaseOverride != null && boot.apiBaseOverride!.trim().isNotEmpty) {
    await auth.setApiBaseUrl(boot.apiBaseOverride!.trim());
  }
  final GoRouter router = createEngineRouter(auth);

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    openNexusAuthHandoff(router, uri);
  });
  final Uri? initialAppLink = await appLinks.getInitialLink();

  runApp(_LynxEngineApp(authProvider: auth, router: router));

  if (initialAppLink != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openNexusAuthHandoff(router, initialAppLink);
    });
  }
}

class _LynxEngineApp extends StatelessWidget {
  final AuthProvider authProvider;
  final GoRouter router;
  const _LynxEngineApp({required this.authProvider, required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider<ProjectProvider>(
          create: (ctx) => ProjectProvider(ctx.read<AuthProvider>()),
        ),
        ChangeNotifierProvider<AssetProvider>(
          create: (ctx) => AssetProvider(ctx.read<AuthProvider>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProjectManager>(
          create: (_) => ProjectManager(),
          update: (ctx, auth, previous) => previous ?? ProjectManager(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final baseTheme = settings.getThemeData();
          return MaterialApp.router(
            title: 'Lynx Engine',
            theme: baseTheme.copyWith(
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: <TargetPlatform, PageTransitionsBuilder>{
                  TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
                },
              ),
            ),
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            themeAnimationDuration: Duration.zero,
            themeAnimationCurve: Curves.linear,
          );
        },
      ),
    );
  }
}
