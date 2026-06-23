import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/providers/auth_provider.dart';
import '../ecosystem/lynx_marketplace.dart';
import '../projects/lynx_local_project_service.dart';
import '../projects/models/project.dart';
import '../projects/providers/project_provider.dart';
import '../../app/providers/settings_provider.dart';
import '../../app/themes/nexus_shell_theme.dart';
import '../../app/themes/lynx_hub_palette.dart';
import '../../app/widgets/lynx_xbox_tile.dart';
import '../../app/widgets/lynx_mark.dart';
import 'lynx_hub_quick_actions.dart';
import 'lynx_launcher_modular_panels.dart';
import 'marketplace_item_detail.dart';

class LynxHubFeed extends StatefulWidget {
  final void Function(String moduleId)? onSelectModule;

  const LynxHubFeed({super.key, this.onSelectModule});

  @override
  State<LynxHubFeed> createState() => _LynxHubFeedState();
}

class _LynxHubFeedState extends State<LynxHubFeed> {
  List<LynxLocalProjectEntry> _local = const [];
  LynxMarketplaceCatalog? _catalog;
  bool _loadingLocal = true;
  bool _loadingStore = false;
  String? _storeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _reloadLocal();
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      await context.read<ProjectProvider>().loadProjects();
    }
    await _loadStore();
  }

  Future<void> _reloadLocal() async {
    setState(() => _loadingLocal = true);
    final list = await loadLynxLocalProjects();
    if (!mounted) return;
    setState(() {
      _local = list;
      _loadingLocal = false;
    });
  }

  Future<void> _loadStore() async {
    setState(() {
      _loadingStore = true;
      _storeError = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      final url = context.read<SettingsProvider>().storeCatalogUrl.trim();
      final cat = await LynxMarketplace.fetchCatalog(
        url,
        cloudDio: auth.isAuthenticated ? auth.http : null,
      );
      if (!mounted) return;
      setState(() {
        _catalog = cat;
        _loadingStore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _storeError = '$e';
        _loadingStore = false;
      });
    }
  }

  String _greeting(String? nickname) {
    final h = DateTime.now().hour;
    final part = h < 12
        ? 'Доброе утро'
        : h < 18
        ? 'Добрый день'
        : 'Добрый вечер';
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return '$part, $nick';
    return part;
  }

  double _hPad(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600 ? 16.0 : 28.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final cloud = context.watch<ProjectProvider>().projects;
    final dateLabel = _formatDateLabel(DateTime.now());
    final hPad = _hPad(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final shell = context.nexusShell;
    final hubBg = shell.contentChrome;

    return ColoredBox(
      color: hubBg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _reloadLocal();
            if (auth.isAuthenticated) {
              await context.read<ProjectProvider>().loadProjects();
            }
            await _loadStore();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (isMobile)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 4),
                    child: _MobileHubHeader(),
                  ),
                ),
              if (!isMobile)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 8),
                    child: Row(
                      children: [
                        Text(
                          'Lynx Hub',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.calendar_today_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          dateLabel[0].toUpperCase() + dateLabel.substring(1),
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 20),
                  child: Text(
                    _greeting(auth.user?.nickname),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _quickStrip(context)),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  title: 'Недавние проекты',
                  action: 'Все',
                  onAction: () => widget.onSelectModule?.call('projects'),
                ),
              ),
              if (_loadingLocal)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else if (_local.isEmpty && cloud.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    child: _emptyCard(
                      context,
                      icon: Icons.folder_open_outlined,
                      title: 'Пока нет проектов',
                      subtitle: 'Создайте локальный проект или войдите для облачных.',
                      action: 'Создать проект',
                      onAction: () => showCreateLynxLocalProjectDialog(context).then((_) => _reloadLocal()),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(context),
                      mainAxisSpacing: isMobile ? 10 : 16,
                      crossAxisSpacing: isMobile ? 10 : 16,
                      childAspectRatio: _projectAspect(context),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final items = _mergedProjects(_local, cloud);
                        if (i >= items.length) return null;
                        return _ProjectFeedCard(
                          item: items[i],
                          onChanged: _reloadLocal,
                        );
                      },
                      childCount: _mergedProjects(_local, cloud).length.clamp(0, 12),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  title: 'Магазин ассетов',
                  action: 'Каталог',
                  onAction: () => widget.onSelectModule?.call('store'),
                ),
              ),
              if (_loadingStore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              else if (_storeError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: _hPad(context)),
                    child: Text(_storeError!, style: TextStyle(color: cs.error, fontSize: 13)),
                  ),
                )
              else
                SliverToBoxAdapter(child: _storeRow(context, _catalog?.items ?? const [])),
              SliverToBoxAdapter(
                child: _sectionHeader(
                  context,
                  title: 'Игры сообщества',
                  action: 'Все',
                  onAction: () => widget.onSelectModule?.call('store'),
                ),
              ),
              SliverToBoxAdapter(child: _communityGamesRow(context, cloud, _catalog?.items ?? const [])),
              if (cloud.any((p) => p.visibility == 'public' || p.shareSlug != null)) ...[
                SliverToBoxAdapter(
                  child: _sectionHeader(
                    context,
                    title: 'Онлайн и доступные',
                    action: null,
                    onAction: null,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridColumns(context),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.82,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final online = cloud
                            .where((p) => p.visibility == 'public' || p.shareSlug != null)
                            .take(8)
                            .toList();
                        if (i >= online.length) return null;
                        return _ProjectFeedCard(
                          item: _FeedProjectItem.cloud(online[i]),
                          onChanged: _reloadLocal,
                        );
                      },
                      childCount: cloud
                          .where((p) => p.visibility == 'public' || p.shareSlug != null)
                          .take(8)
                          .length,
                    ),
                  ),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  int _gridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return 2;
    if (w >= 1400) return 4;
    if (w >= 1000) return 3;
    return 2;
  }

  double _projectAspect(BuildContext context) {
    return MediaQuery.sizeOf(context).width < 600 ? 1.55 : 0.82;
  }

  List<_FeedProjectItem> _mergedProjects(
    List<LynxLocalProjectEntry> local,
    List<Project> cloud,
  ) {
    final out = <_FeedProjectItem>[
      ...local.map(_FeedProjectItem.local),
      ...cloud.map(_FeedProjectItem.cloud),
    ];
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out.take(12).toList();
  }

  Widget _quickStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = [
      _QuickChip(
        icon: Icons.add_rounded,
        label: 'Новый проект',
        onTap: () => showCreateLynxLocalProjectDialog(context).then((_) => _reloadLocal()),
      ),
      _QuickChip(
        icon: Icons.upload_file_outlined,
        label: 'Импорт',
        onTap: () => importProjectZipFromPicker(context).then((_) => _reloadLocal()),
      ),
      _QuickChip(
        icon: Icons.memory_outlined,
        label: 'Lynx Engine',
        onTap: () => context.push('/engine-install'),
      ),
      _QuickChip(
        icon: Icons.sports_esports_outlined,
        label: 'Tetris demo',
        onTap: () => exportTetrisDemoLynxProject(context),
      ),
    ];

    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: _hPad(context)),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final c = chips[i];
          return Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: c.onTap,
              child: Container(
                width: 148,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(c.icon, color: cs.primary, size: 28),
                    const Spacer(),
                    Text(
                      c.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _communityGamesRow(
    BuildContext context,
    List<Project> cloud,
    List<LynxMarketplaceItem> catalog,
  ) {
    final cs = Theme.of(context).colorScheme;
    final hPad = _hPad(context);
    final games = <_FeedProjectItem>[
      ...cloud
          .where((p) => p.visibility == 'public' || p.shareSlug != null)
          .map(_FeedProjectItem.cloud),
      for (final it in catalog.where((i) => i.kind == 'game' || i.category == 'games'))
        _FeedProjectItem.catalogGame(it),
    ];
    if (games.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
        child: Text(
          'Пока нет опубликованных игр. Выложите проект в Lynx Cloud.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
      );
    }
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return SizedBox(
      height: isMobile ? 240 : 290,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 20),
        scrollDirection: Axis.horizontal,
        itemCount: games.length.clamp(0, 12),
        separatorBuilder: (_, __) => SizedBox(width: isMobile ? 10 : 12),
        itemBuilder: (ctx, i) => LynxXboxTile(
          title: games[i].name,
          subtitle: games[i].cloud?.shareSlug != null ? 'Сообщество' : 'Локально',
          icon: Icons.sports_esports_outlined,
          badge: 'ИГРА',
          width: isMobile ? 160 : 200,
          onTap: () {},
        ),
      ),
    );
  }

  Widget _storeRow(BuildContext context, List<LynxMarketplaceItem> items) {
    final hPad = _hPad(context);
    final slice = items.where((m) => m.kind != 'game' && m.category != 'games').take(10).toList();
    if (slice.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
        child: Text('Каталог пуст или недоступен.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      );
    }
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return SizedBox(
      height: isMobile ? 240 : 290,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 16),
        scrollDirection: Axis.horizontal,
        itemCount: slice.length,
        separatorBuilder: (_, __) => SizedBox(width: isMobile ? 10 : 12),
        itemBuilder: (ctx, i) => LynxXboxTile(
          title: slice[i].title,
          subtitle: slice[i].author ?? slice[i].description,
          imageUrl: slice[i].imageUrl,
          icon: slice[i].category == '3d' ? Icons.view_in_ar : Icons.extension_outlined,
          badge: slice[i].kind.toUpperCase(),
          width: isMobile ? 160 : 200,
          onTap: () => openMarketplaceItemDetail(
            context,
            item: slice[i],
            primaryActionLabel: 'Открыть в магазине',
            onPrimaryAction: () => widget.onSelectModule?.call('store'),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    String? action,
    VoidCallback? onAction,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 14),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          if (action != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }

  Widget _emptyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onAction,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: cs.brightness == Brightness.light
                  ? const Color(0xFF18181B)
                  : cs.primary,
              foregroundColor: cs.brightness == Brightness.light
                  ? Colors.white
                  : cs.onPrimary,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

String _formatDateLabel(DateTime dt) {
  const weekdays = [
    'понедельник',
    'вторник',
    'среда',
    'четверг',
    'пятница',
    'суббота',
    'воскресенье',
  ];
  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  final wd = weekdays[dt.weekday - 1];
  return '$wd, ${dt.day} ${months[dt.month - 1]}';
}

class _QuickChip {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.onTap});
}

enum _FeedProjectKind { local, cloud }

class _FeedProjectItem {
  final _FeedProjectKind kind;
  final String id;
  final String name;
  final DateTime updatedAt;
  final String? localPath;
  final Project? cloud;
  final bool isViewerOnly;

  _FeedProjectItem._({
    required this.kind,
    required this.id,
    required this.name,
    required this.updatedAt,
    this.localPath,
    this.cloud,
    this.isViewerOnly = false,
  });

  factory _FeedProjectItem.local(LynxLocalProjectEntry e) => _FeedProjectItem._(
    kind: _FeedProjectKind.local,
    id: e.path,
    name: e.name,
    updatedAt: e.updatedAt,
    localPath: e.path,
  );

  factory _FeedProjectItem.cloud(Project p) => _FeedProjectItem._(
    kind: _FeedProjectKind.cloud,
    id: p.id,
    name: p.name,
    updatedAt: p.updatedAt,
    cloud: p,
    isViewerOnly: p.isViewerOnly,
  );

  factory _FeedProjectItem.catalogGame(LynxMarketplaceItem it) => _FeedProjectItem._(
    kind: _FeedProjectKind.cloud,
    id: it.id,
    name: it.title,
    updatedAt: DateTime.now(),
  );
}

class _ProjectFeedCard extends StatelessWidget {
  final _FeedProjectItem item;
  final VoidCallback onChanged;

  const _ProjectFeedCard({required this.item, required this.onChanged});

  Color _accent(String name) {
    final hues = [0xFF4C9AFF, 0xFFE91E8C, 0xFF34D399, 0xFFF59E0B, 0xFF8B5CF6];
    return Color(hues[name.hashCode.abs() % hues.length]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accent(item.name);
    final date = '${item.updatedAt.day.toString().padLeft(2, '0')}.${item.updatedAt.month.toString().padLeft(2, '0')}.${item.updatedAt.year}';

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.22)),
                    child: Center(
                      child: Icon(
                        item.kind == _FeedProjectKind.local
                            ? Icons.folder_special_outlined
                            : Icons.cloud_outlined,
                        size: 48,
                        color: accent,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz, color: cs.onSurface.withValues(alpha: 0.8)),
                      onSelected: (v) async {
                        if (v == 'download' && item.localPath != null) {
                          exportLynxLocalProjectZip(context, projectRoot: item.localPath!);
                        }
                        if (v == 'open') _open(context);
                        if (v == 'delete' && item.localPath != null) {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Удалить из списка?'),
                              content: const Text('Проект исчезнет из лаунчера. Папка на диске останется.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await removeLynxLocalProject(item.localPath!);
                            onChanged();
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'open', child: Text('Открыть')),
                        if (item.localPath != null && !kIsWeb) ...[
                          const PopupMenuItem(
                            value: 'download',
                            child: Text('Скачать .lynxproject'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить из списка'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.kind == _FeedProjectKind.local
                        ? 'Локальный · $date'
                        : '${item.isViewerOnly ? 'Просмотр' : 'Облако'} · $date',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (item.kind == _FeedProjectKind.local && item.localPath != null) {
      openLynxLocalProjectInEditor(
        context,
        projectPath: item.localPath!,
        projectName: item.name,
      );
      return;
    }
    final p = item.cloud;
    if (p != null) {
      context.read<ProjectProvider>().setCurrentProject(p);
      context.push('/project/${p.id}');
    }
  }
}

class _StoreFeedCard extends StatelessWidget {
  final LynxMarketplaceItem item;
  final VoidCallback? onTap;

  const _StoreFeedCard({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 168,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.kind == 'template'
                      ? Icons.dashboard_customize_outlined
                      : Icons.extension_outlined,
                  color: cs.primary,
                  size: 32,
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  item.kind == 'template' ? 'Шаблон' : 'Ассет',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHubHeader extends StatelessWidget {
  const _MobileHubHeader();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;
    final nick = auth.user?.nickname.trim();
    final label = (nick != null && nick.isNotEmpty)
        ? nick.substring(0, 1).toUpperCase()
        : 'L';

    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showLynxAccountSheet(context),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.85),
                child: Text(
                  label,
                  style: TextStyle(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nick != null && nick.isNotEmpty ? '@$nick' : 'Гость',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Lynx Hub',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.tune_outlined),
          tooltip: 'Настройки',
          onPressed: () {
            if (MediaQuery.sizeOf(context).width < 600) {
              context.push('/launcher-settings');
            } else {
              showLynxLauncherHubSheet(context);
            }
          },
        ),
        const LynxMark(size: 28),
      ],
    );
  }
}
