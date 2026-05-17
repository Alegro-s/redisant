import 'package:app_links/app_links.dart';
import 'package:client/app/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app/router.dart';
import 'features/auth/nexus_deep_link.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/engine/project_manager.dart';
import 'features/home/home_dashboard_provider.dart';
import 'features/projects/providers/project_provider.dart';
import 'features/assets/providers/asset_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = AuthProvider();
  final GoRouter router = createAppRouter(authProvider);

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    openNexusAuthHandoff(router, uri);
  });
  final Uri? initialAppLink = await appLinks.getInitialLink();

  runApp(MyApp(authProvider: authProvider, router: router));

  if (initialAppLink != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openNexusAuthHandoff(router, initialAppLink);
    });
  }
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final GoRouter router;
  const MyApp({super.key, required this.authProvider, required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => HomeDashboardProvider()),
        ChangeNotifierProvider<ProjectProvider>(
          create: (ctx) => ProjectProvider(ctx.read<AuthProvider>()),
        ),
        ChangeNotifierProvider<AssetProvider>(
          create: (ctx) => AssetProvider(ctx.read<AuthProvider>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ProjectManager>(
          create: (ctx) => ProjectManager(),
          update: (ctx, auth, previous) => previous ?? ProjectManager(),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final baseTheme = settings.getThemeData();
          return MaterialApp.router(
            title: 'Lynx Launcher',
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