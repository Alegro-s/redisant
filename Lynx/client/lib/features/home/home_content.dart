import 'package:client/app/themes/nexus_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import '../auth/providers/auth_provider.dart';
import '../projects/providers/project_provider.dart';
import 'home_dashboard_provider.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<ProjectProvider>().loadProjects();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeDashboardProvider, AuthProvider>(
      builder: (context, dash, auth, _) {
        if (!dash.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final cs = Theme.of(context).colorScheme;
        return ColoredBox(
          color: cs.surface,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'Lynx Hub',
                        style: NexusTheme.standaloneTextStyle(
                          GoogleFonts.jetBrainsMono(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                          fallbackFontSize: 18,
                        ),
                      ),
                      const Spacer(),
                      _HomeQuickMenuButton(dash: dash),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final narrow = c.maxWidth < 560;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LynxHubHeroCard(narrow: narrow),
                          const SizedBox(height: 14),
                          _CloudMetricsStrip(narrow: narrow),
                        ],
                      );
                    },
                  ),
                ),
                if (dash.editorMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    child: Material(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: cs.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Перетащите блоки за ручку ⋮⋮. Порядок сохраняется на устройстве.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                                softWrap: true,
                              ),
                            ),
                            TextButton(
                              onPressed: () => dash.resetBlockOrder(),
                              child: const Text('Сброс'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: dash.editorMode
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          itemCount: dash.blockOrder.length,
                          onReorder: dash.reorderBlocks,
                          itemBuilder: (context, index) {
                            final id = dash.blockOrder[index];
                            return _EditorRow(
                              key: ValueKey(id),
                              index: index,
                              child: _HomeBlockCard(
                                id: id,
                                margin: const EdgeInsets.only(bottom: 20),
                              ),
                            );
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          children: [
                            for (
                              var i = 0;
                              i < dash.blockOrder.length;
                              i++
                            ) ...[
                              if (i > 0) const SizedBox(height: 20),
                              _HomeBlockCard(id: dash.blockOrder[i]),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeQuickMenuButton extends StatelessWidget {
  final HomeDashboardProvider dash;

  const _HomeQuickMenuButton({required this.dash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Меню',
      onPressed: () => _showQuickMenu(context),
      icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
    );
  }

  void _showQuickMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Профиль'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/profile');
              },
            ),
            ListTile(
              leading: Icon(
                dash.editorMode
                    ? Icons.check_circle_outline
                    : Icons.tune_rounded,
              ),
              title: Text(
                dash.editorMode
                    ? 'Готово с модулями'
                    : 'Настроить порядок модулей',
              ),
              onTap: () {
                Navigator.pop(ctx);
                dash.setEditorMode(!dash.editorMode);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorRow extends StatelessWidget {
  final int index;
  final Widget child;

  const _EditorRow({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 12),
              child: Icon(
                Icons.drag_handle,
                color: cs.onSurfaceVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LynxHubHeroCard extends StatelessWidget {
  final bool narrow;

  const _LynxHubHeroCard({required this.narrow});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        );
    final subStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.4,
        );
    final ctas = [
      FilledButton.icon(
        onPressed: () => context.push('/projects'),
        icon: const Icon(Icons.folder_open_rounded, size: 18),
        label: const Text('Мои проекты'),
      ),
      OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Документация и туториалы — см. репозиторий docs/ и GAME_AUTHOR.md.',
              ),
            ),
          );
        },
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: const Text('Учиться'),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primaryContainer.withValues(alpha: 0.5),
            cs.surfaceContainerHighest.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(narrow ? 16 : 22),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Добро пожаловать в Lynx Hub', style: titleStyle),
                  const SizedBox(height: 8),
                  Text(
                    'Облачные проекты, редактор сцен, Lua и каталог Lynx Cloud — в одном клиенте.',
                    style: subStyle,
                  ),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: ctas),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Добро пожаловать в Lynx Hub', style: titleStyle),
                        const SizedBox(height: 8),
                        Text(
                          'Облачные проекты, редактор сцен, Lua и каталог Lynx Cloud — в одном клиенте.',
                          style: subStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ctas[0],
                      const SizedBox(height: 8),
                      ctas[1],
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _CloudMetricsStrip extends StatefulWidget {
  final bool narrow;

  const _CloudMetricsStrip({required this.narrow});

  @override
  State<_CloudMetricsStrip> createState() => _CloudMetricsStripState();
}

class _CloudMetricsStripState extends State<_CloudMetricsStrip> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projects = context.watch<ProjectProvider>().projects.length;
    final cards = [
      _MetricTileData(
        icon: Icons.folder_shared_outlined,
        label: 'Проекты',
        value: '$projects',
        hint: 'в облаке',
      ),
      _MetricTileData(
        icon: Icons.storage_outlined,
        label: 'Хранилище',
        value: '—',
        hint: 'скоро метрики',
      ),
    ];
    if (widget.narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _MetricTile(data: cards[i], cs: cs),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _MetricTile(data: cards[i], cs: cs)),
        ],
      ],
    );
  }
}

class _MetricTileData {
  final IconData icon;
  final String label;
  final String value;
  final String hint;

  const _MetricTileData({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });
}

class _MetricTile extends StatelessWidget {
  final _MetricTileData data;
  final ColorScheme cs;

  const _MetricTile({required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(data.icon, size: 22, color: cs.primary.withValues(alpha: 0.9)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    data.hint,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBlockCard extends StatelessWidget {
  final String id;
  final EdgeInsetsGeometry margin;

  const _HomeBlockCard({required this.id, this.margin = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget inner;
    switch (id) {
      case 'profile':
        inner = const _ProfileHeaderBlock();
        break;
      case 'activity':
        inner = const _ActivityBlock();
        break;
      case 'projects':
        inner = const _RecentProjectsBlock();
        break;
      default:
        inner = const SizedBox.shrink();
    }
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark
                ? 0.22
                : 0.92,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.18
                    : 0.06,
              ),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: cs.primary.withValues(alpha: 0.65)),
                Expanded(child: inner),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderBlock extends StatelessWidget {
  const _ProfileHeaderBlock();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final cs = Theme.of(context).colorScheme;
    final coins = user?.settings['coins'];
    final coinsLabel = coins is num ? '${coins.toInt()} монет' : '0 монет';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.primaryContainer,
                backgroundImage: _avatarBg(user?.avatarUrl),
                child: _avatarFg(user?.avatarUrl, cs.primary),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user != null && user.fullName.isNotEmpty)
                      ? user.fullName
                      : 'Пользователь',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  coinsLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? cs.secondary
                        : cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBlock extends StatefulWidget {
  const _ActivityBlock();

  @override
  State<_ActivityBlock> createState() => _ActivityBlockState();
}

class _ActivityBlockState extends State<_ActivityBlock> {
  List<Map<String, dynamic>>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  List<Map<String, dynamic>> _recentChatsOnly(List<Map<String, dynamic>> src) {
    final out = <Map<String, dynamic>>[];
    final seenPeers = <String>{};
    for (final item in src) {
      final peerId = item['peer_id']?.toString() ?? '';
      if (peerId.isEmpty || seenPeers.contains(peerId)) continue;
      seenPeers.add(peerId);
      out.add(item);
      if (out.length >= 2) break;
    }
    return out;
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      if (mounted) {
        setState(() {
          _loading = false;
          _items = [];
        });
      }
      return;
    }
    try {
      final r = await auth.http.get<List<dynamic>>('/chat/recent');
      final raw = r.data ?? <dynamic>[];
      final list = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          list.add(e);
        } else if (e is Map) {
          list.add(Map<String, dynamic>.from(e));
        }
      }
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
          _error = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        final status = e.response?.statusCode ?? 0;
        if (status == 404) {
          setState(() {
            _loading = false;
            _error = null;
            _items = [];
          });
          return;
        }
        setState(() {
          _loading = false;
          _error = e.response?.data is Map
              ? (e.response!.data as Map)['error']?.toString()
              : e.message;
          _items = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _items = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chats = (_items == null)
        ? const <Map<String, dynamic>>[]
        : _recentChatsOnly(_items!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Последние сообщения',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Обновить',
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(_error!, style: TextStyle(fontSize: 12, color: cs.error))
          else if (_items == null || _items!.isEmpty)
            Text(
              'Нет сообщений в чатах с друзьями. Добавьте друзей и напишите в модуле «Мессенджер».',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < chats.length && i < 2; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: cs.outline.withValues(alpha: 0.25),
                    ),
                  _activityTile(
                    context,
                    title: chats[i]['title']?.toString() ?? 'Чат',
                    subtitle: 'Последняя активность в этом чате',
                    showDot: !(chats[i]['is_outgoing'] == true),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _activityTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool showDot,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              if (showDot)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEC4899),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentProjectsBlock extends StatelessWidget {
  const _RecentProjectsBlock();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projects = context.watch<ProjectProvider>().projects;
    final recent = projects.take(8).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Новые проекты',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/projects'),
                  child: const Text('Все'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 168,
            child: recent.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        'Пока нет проектов',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final p = recent[i];
                      return _ProjectStripCard(
                        name: p.name,
                        onTap: () => context.push('/project/${p.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectStripCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ProjectStripCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 118,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.folder_special_outlined,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                    size: 40,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

ImageProvider? _avatarBg(String? url) {
  if (url == null || url.isEmpty) return null;
  return NetworkImage(url);
}

Widget? _avatarFg(String? url, Color primary) {
  if (url != null && url.isNotEmpty) return null;
  return Icon(Icons.person_rounded, color: primary, size: 32);
}
