import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../app/providers/settings_provider.dart';
import '../../app/themes/nexus_shell_theme.dart';
import '../auth/providers/auth_provider.dart';
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedModuleId = 'home';
  bool _hideMobileNavForChat = false;
  bool _hasUnreadMessenger = false;
  String? _lastSeenIncomingMessageId;
  Timer? _chatPollTimer;

  static const double _kWideShell = 960;
  static const double _kMediumShell = 600;
  static const double _sidebarWidth = 252;

  @override
  void initState() {
    super.initState();
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
        return const HomeContent();
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
      final wide = w >= _kWideShell;
      final gradientTop =
          Color.lerp(shell.contentChrome, cs.primary, 0.045) ??
          shell.contentChrome;
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientTop, shell.contentChrome, shell.contentChrome],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            children: [
              _buildSidebar(
                visibleModules,
                settings,
                shell,
                showHeaderBrand: wide,
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: shell.sidebarBorder,
              ),
              Expanded(
                child: ColoredBox(
                  color: Colors.transparent,
                  child: _buildModuleScreen(_selectedModuleId),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildMobileShell(visibleModules, settings, cs, shell);
  }

  Widget _buildSidebar(
    List<Map<String, dynamic>> visibleModules,
    SettingsProvider settings,
    NexusShellTheme shell, {
    required bool showHeaderBrand,
  }) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: _sidebarWidth,
      child: ColoredBox(
        color: shell.sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                showHeaderBrand ? 16 : 12,
                14,
                showHeaderBrand ? 8 : 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lynx Hub',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: showHeaderBrand ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: cs.onSurface,
                    ).copyWith(inherit: false),
                  ),
                  if (showHeaderBrand)
                    Text(
                      'создавайте и хостите игры',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'МОДУЛИ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: shell.sidebar,
                  shadowColor: Colors.transparent,
                ),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: true),
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 6),
                    itemCount: visibleModules.length,
                    onReorder: (int oldIndex, int newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) newIndex -= 1;
                        final copy = List<Map<String, dynamic>>.from(
                          visibleModules,
                        );
                        final item = copy.removeAt(oldIndex);
                        copy.insert(newIndex, item);
                        settings.updateModulesOrder(
                          copy
                              .map((m) => m['id']?.toString() ?? '')
                              .where((e) => e.isNotEmpty)
                              .toList(),
                        );
                      });
                    },
                    itemBuilder: (ctx, i) {
                      final mod = visibleModules[i];
                      final mid = mod['id']?.toString() ?? 'idx_$i';
                      return _SidebarModuleTile(
                        key: ValueKey('mod_$mid'),
                        index: i,
                        module: mod,
                        selected: _selectedModuleId == mid,
                        shell: shell,
                        onTap: () => setState(() => _selectedModuleId = mid),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
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
    List<Map<String, dynamic>> mainItems = [];
    Map<String, dynamic>? moreItem;
    if (visibleModules.length > 5) {
      mainItems = visibleModules.sublist(0, 4);
      moreItem = {'id': 'more', 'title': 'Ещё', 'icon': Icons.more_horiz};
    } else {
      mainItems = visibleModules;
    }

    final gradientTop =
        Color.lerp(shell.contentChrome, cs.primary, 0.05) ??
        shell.contentChrome;
    final destinations = _mobileDestinations(mainItems, moreItem);
    final navIndex = _mobileNavIndex(mainItems, moreItem);
    final safeNavIndex = destinations.isEmpty
        ? 0
        : navIndex.clamp(0, destinations.length - 1);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [gradientTop, shell.contentChrome],
            ),
          ),
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
                  _showMoreModulesSheet(visibleModules);
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
          label: (m['title']?.toString() ?? '…').split(' ').first,
        ),
      ),
      if (moreItem != null)
        const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Ещё'),
    ];
    if (out.isEmpty) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_work_outlined), label: 'Hub'),
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

class _SidebarModuleTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> module;
  final bool selected;
  final NexusShellTheme shell;
  final VoidCallback onTap;

  const _SidebarModuleTile({
    super.key,
    required this.index,
    required this.module,
    required this.selected,
    required this.shell,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color: selected ? shell.sidebarSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 40,
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  margin: const EdgeInsets.only(left: 4, right: 6),
                  decoration: BoxDecoration(
                    color: selected ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  module['icon'] is IconData
                      ? module['icon'] as IconData
                      : Icons.widgets_outlined,
                  size: 18,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    module['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 16,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
