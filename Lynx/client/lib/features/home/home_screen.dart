import 'package:flutter/material.dart';
import 'lynx_launcher_modular_panels.dart';
import 'lynx_launcher_profile_menu.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../app/providers/settings_provider.dart';
import '../../app/themes/nexus_shell_theme.dart';
import '../auth/providers/auth_provider.dart';
import '../arcade/arcade_screen.dart';
import 'home_content.dart';
import '../messenger/messenger_screen.dart';
import '../projects/screens/projects_screen.dart';
import 'asset_store_catalog_screen.dart';
import 'news_feed_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderModule(
    title: 'Библиотека',
    icon: Icons.library_books_outlined,
    hint: 'Ассеты и шаблоны проектов.',
  );
}

class GithubScreen extends StatelessWidget {
  const GithubScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderModule(
    title: 'GitHub',
    icon: Icons.code_outlined,
    hint: 'Репозитории и интеграции.',
  );
}

class AIScreen extends StatelessWidget {
  const AIScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderModule(
    title: 'ИИ',
    icon: Icons.smart_toy_outlined,
    hint: 'Помощники для кода и контента.',
  );
}

class TelemostScreen extends StatelessWidget {
  const TelemostScreen({super.key});
  @override
  Widget build(BuildContext context) => const _PlaceholderModule(
    title: 'Звонки',
    icon: Icons.video_call_outlined,
    hint: 'Голос и видео внутри проекта.',
  );
}

class _PlaceholderModule extends StatelessWidget {
  final String title;
  final IconData icon;
  final String hint;
  const _PlaceholderModule({
    required this.title,
    required this.icon,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: cs.primary.withValues(alpha: 0.85)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String? initialModule;

  const HomeScreen({super.key, this.initialModule});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedModuleId = 'home';
  bool _hideMobileNavForChat = false;
  bool _hasUnreadMessenger = false;
  String? _lastSeenIncomingMessageId;
  Timer? _chatPollTimer;
  final GlobalKey _profileAvatarKey = GlobalKey();
  final GlobalKey _hubMenuKey = GlobalKey();

  static const double _kMediumShell = 600;
  static const double _iconRailWidth = 68;

  static const List<(String id, String label, IconData icon)> _mobileNavOrder = [
    ('home', 'Главная', Icons.home_outlined),
    ('messenger', 'Мессенджер', Icons.chat_bubble_outline),
    ('store', 'Магазин', Icons.storefront_outlined),
    ('projects', 'Проекты', Icons.folder_outlined),
    ('news', 'Новости', Icons.newspaper_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final module = widget.initialModule?.trim();
    if (module != null && module.isNotEmpty) {
      _selectedModuleId = module;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUnreadMessenger();
      _chatPollTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => _refreshUnreadMessenger(),
      );
    });
  }

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUnreadMessenger() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;
    try {
      final r = await auth.http.get<List<dynamic>>('/chat/recent');
      final rows = r.data ?? const <dynamic>[];
      String? newestIncoming;
      for (final row in rows) {
        final map = row is Map<String, dynamic>
            ? row
            : (row is Map ? Map<String, dynamic>.from(row) : null);
        if (map == null) continue;
        if (map['is_outgoing'] == true) continue;
        newestIncoming = map['message_id']?.toString();
        if (newestIncoming != null && newestIncoming.isNotEmpty) break;
      }
      if (!mounted) return;
      if (_selectedModuleId == 'messenger' || _hideMobileNavForChat) {
        setState(() {
          _hasUnreadMessenger = false;
          if (newestIncoming != null && newestIncoming.isNotEmpty) {
            _lastSeenIncomingMessageId = newestIncoming;
          }
        });
        return;
      }
      setState(() {
        _hasUnreadMessenger =
            newestIncoming != null &&
            newestIncoming.isNotEmpty &&
            newestIncoming != _lastSeenIncomingMessageId;
      });
    } catch (_) {}
  }

  Widget _buildModuleScreen(String moduleId) {
    switch (moduleId) {
      case 'home':
        return HomeContent(
          onSelectModule: (id) => setState(() => _selectedModuleId = id),
        );
      case 'projects':
        return const ProjectsScreen();
      case 'messenger':
        return MessengerScreen(
          onChatOpenChanged: (open) {
            if (!mounted) return;
            setState(() {
              _hideMobileNavForChat = open;
              if (open) _hasUnreadMessenger = false;
            });
          },
        );
      case 'store':
        return const AssetStoreCatalogScreen();
      case 'arcade':
        return const ArcadeScreen();
      case 'library':
        return const LibraryScreen();
      case 'news':
        return const NewsFeedScreen();
      case 'github':
        return const GithubScreen();
      case 'ai':
        return const AIScreen();
      case 'telemost':
        return const TelemostScreen();
      default:
        return const HomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    var visibleModules = settings.getVisibleModulesInOrder();
    if (visibleModules.isEmpty) {
      visibleModules = [
        Map<String, dynamic>.from(
          availableModules.firstWhere(
            (m) => m['id'] == 'home',
            orElse: () => availableModules.first,
          ),
        ),
      ];
    }
    final visibleIds = visibleModules
        .map((m) => m['id']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
    if (!visibleIds.contains(_selectedModuleId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedModuleId = 'home');
      });
    }
    final w = MediaQuery.sizeOf(context).width;
    final shell = context.nexusShell;
    final cs = Theme.of(context).colorScheme;

    if (w >= _kMediumShell) {
      final shell = context.nexusShell;
      return ColoredBox(
        color: shell.contentChrome,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              _buildIconRail(visibleModules, shell),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(anim);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_selectedModuleId),
                    child: _buildModuleScreen(_selectedModuleId),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildMobileShell(visibleModules, settings, cs, shell);
  }

  Widget _buildIconRail(
    List<Map<String, dynamic>> visibleModules,
    NexusShellTheme shell,
  ) {
    final railBg = shell.sidebar;
    return SizedBox(
      width: _iconRailWidth,
      child: ColoredBox(
        color: railBg,
        child: Column(
          children: [
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: const LynxBrandMark(size: 28),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: visibleModules.length,
                itemBuilder: (ctx, i) {
                  final mod = visibleModules[i];
                  final mid = mod['id']?.toString() ?? 'idx_$i';
                  final selected = _selectedModuleId == mid;
                  return _IconRailTile(
                    module: mod,
                    selected: selected,
                    shell: shell,
                    showBadge: mid == 'messenger' && _hasUnreadMessenger,
                    onTap: () => setState(() => _selectedModuleId = mid),
                  );
                },
              ),
            ),
            LynxLauncherHubButton(
              hubKey: _hubMenuKey,
              onTap: () {
                final box = _hubMenuKey.currentContext?.findRenderObject();
                if (box is RenderBox) {
                  showLynxLauncherHubMenu(context, anchor: box);
                }
              },
            ),
            LynxProfileAvatarButton(
              avatarKey: _profileAvatarKey,
              onTap: () {
                final box = _profileAvatarKey.currentContext?.findRenderObject();
                if (box is RenderBox) {
                  showLynxLauncherProfileMenu(context, anchor: box);
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileShell(
    List<Map<String, dynamic>> visibleModules,
    SettingsProvider settings,
    ColorScheme cs,
    NexusShellTheme shell,
  ) {
    final enabledIds = settings.enabledModules;
    final mainItems = <Map<String, dynamic>>[];
    for (final spec in _mobileNavOrder) {
      if (!enabledIds.contains(spec.$1)) continue;
      final fromCatalog = visibleModules.cast<Map<String, dynamic>?>().firstWhere(
        (m) => m?['id'] == spec.$1,
        orElse: () => null,
      );
      mainItems.add({
        'id': spec.$1,
        'title': fromCatalog?['title'] ?? spec.$2,
        'mobileLabel': spec.$2,
        'icon': spec.$3,
      });
    }
    final extraModules = visibleModules
        .where((m) {
          final id = m['id']?.toString() ?? '';
          return id.isNotEmpty &&
              !_mobileNavOrder.any((e) => e.$1 == id) &&
              enabledIds.contains(id);
        })
        .toList();
    Map<String, dynamic>? moreItem;
    if (extraModules.isNotEmpty) {
      moreItem = {'id': 'more', 'title': 'Ещё', 'icon': Icons.more_horiz_outlined};
    }

    final destinations = _mobileDestinations(mainItems, moreItem);
    final navIndex = _mobileNavIndex(mainItems, moreItem);
    final safeNavIndex = destinations.isEmpty
        ? 0
        : navIndex.clamp(0, destinations.length - 1);

    return Scaffold(
      backgroundColor: shell.contentChrome,
      body: SafeArea(
        child: ColoredBox(
          color: shell.contentChrome,
          child: _buildModuleScreen(_selectedModuleId),
        ),
      ),
      bottomNavigationBar: _hideMobileNavForChat
          ? null
          : NavigationBar(
              selectedIndex: safeNavIndex,
              onDestinationSelected: (index) {
                if (index < mainItems.length) {
                  setState(
                    () => _selectedModuleId =
                        mainItems[index]['id']?.toString() ?? 'home',
                  );
                } else {
                  _showMoreModulesSheet(extraModules.isEmpty ? visibleModules : extraModules);
                }
              },
              destinations: destinations,
            ),
    );
  }

  int _mobileNavIndex(List<Map<String, dynamic>> mainItems, Map? moreItem) {
    final index = mainItems.indexWhere((m) => m['id'] == _selectedModuleId);
    if (index != -1) return index;
    return moreItem != null ? mainItems.length : 0;
  }

  List<NavigationDestination> _mobileDestinations(
    List<Map<String, dynamic>> mainItems,
    Map<String, dynamic>? moreItem,
  ) {
    final out = <NavigationDestination>[
      ...mainItems.map(
        (m) => NavigationDestination(
          icon: _destinationIcon(m),
          label: m['mobileLabel']?.toString() ??
              m['title']?.toString() ??
              '…',
        ),
      ),
      if (moreItem != null)
        NavigationDestination(
          icon: Icon(moreItem['icon'] as IconData? ?? Icons.more_horiz_outlined),
          label: moreItem['title']?.toString() ?? 'Ещё',
        ),
    ];
    if (out.isEmpty) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Главная',
        ),
      ];
    }
    return out;
  }

  Widget _destinationIcon(Map<String, dynamic> module) {
    final id = module['id']?.toString() ?? '';
    final baseIcon = Icon(
      module['icon'] is IconData
          ? module['icon'] as IconData
          : Icons.widgets_outlined,
    );
    if (id != 'messenger' || !_hasUnreadMessenger) return baseIcon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        const Positioned(
          right: -2,
          top: -2,
          child: SizedBox(
            width: 9,
            height: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF43F5E),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMoreModulesSheet(List<Map<String, dynamic>> allModules) {
    final shell = context.nexusShell;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: shell.sidebar,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: allModules.map((module) {
              return ListTile(
                leading: Icon(
                  module['icon'] is IconData
                      ? module['icon'] as IconData
                      : Icons.widgets_outlined,
                ),
                title: Text(module['title']?.toString() ?? ''),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(
                    () =>
                        _selectedModuleId = module['id']?.toString() ?? 'home',
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _IconRailTile extends StatelessWidget {
  final Map<String, dynamic> module;
  final bool selected;
  final NexusShellTheme shell;
  final bool showBadge;
  final VoidCallback onTap;

  const _IconRailTile({
    required this.module,
    required this.selected,
    required this.shell,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = module['icon'] is IconData
        ? module['icon'] as IconData
        : Icons.widgets_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: module['title']?.toString() ?? '',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? shell.sidebarSelected.withValues(alpha: 0.9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.72),
                  ),
                  if (showBadge)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4C9AFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
