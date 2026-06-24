import 'package:app_links/app_links.dart';
import 'package:client/app/engine_bootstrap.dart';
import 'package:client/app/engine_entry_gate.dart';
import 'package:client/app/providers/settings_provider.dart';
import 'package:client/app/router_engine.dart';
import 'package:client/features/auth/nexus_deep_link.dart';
import 'package:client/features/auth/providers/auth_provider.dart';
import 'package:client/features/engine/project_manager.dart';
import 'package:client/features/plugins/lynx_plugin_registry.dart';
import 'package:client/features/projects/providers/project_provider.dart';
import 'package:client/features/assets/providers/asset_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Lynx Engine — студия: редактор + Play + сборка.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LynxPluginRegistry.instance.ensureInitialized();
  await EngineBootstrap.ensureInitialized();
  final boot = EngineBootstrap.instance;

  if (await shouldShowEngineLauncherGate(boot)) {
    runApp(const _LynxEngineGateApp());
    return;
  }

  final auth = AuthProvider();
  if (boot.apiBaseOverride != null && boot.apiBaseOverride!.trim().isNotEmpty) {
    await auth.setApiBaseUrl(boot.apiBaseOverride!.trim());
  }
  final GoRouter router = createEngineRouter(auth);

  Uri? initialAppLink;
  if (!kIsWeb) {
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) {
      openNexusAuthHandoff(router, uri);
    });
    initialAppLink = await appLinks.getInitialLink();
  } else {
    initialAppLink = Uri.base;
  }

  runApp(_LynxEngineApp(authProvider: auth, router: router));

  if (initialAppLink != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openNexusAuthHandoff(router, initialAppLink!);
    });
  }
}

class _LynxEngineGateApp extends StatelessWidget {
  const _LynxEngineGateApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lynx Engine',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade600),
                const SizedBox(height: 20),
                const Text(
                  'Lynx Engine',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Запустите студию через Lynx Launcher:\n'
                  'Проекты → Работать, или установите ядро в центре Lynx Engine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
