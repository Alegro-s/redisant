import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/themes/lynx_hub_palette.dart';
import '../../app/widgets/lynx_xbox_tile.dart';

import '../auth/providers/auth_provider.dart';
import '../../app/providers/settings_provider.dart';
import '../ecosystem/lynx_marketplace.dart';
import '../projects/lynx_local_project_service.dart';
import 'marketplace_item_detail.dart';

class AssetStoreCatalogScreen extends StatefulWidget {
  const AssetStoreCatalogScreen({super.key});

  @override
  State<AssetStoreCatalogScreen> createState() => _AssetStoreCatalogScreenState();
}

class _AssetStoreCatalogScreenState extends State<AssetStoreCatalogScreen> {
  LynxMarketplaceCatalog? _catalog;
  String? _error;
  bool _loading = false;
  final _searchCtrl = TextEditingController();
  String _category = 'all';

  static const _kCategories = <String, String>{
    'all': 'Все',
    'games': 'Игры',
    'plugins': 'Плагины',
    '3d': '3D',
    '2d': '2D',
    'audio': 'Аудио',
    'templates': 'Шаблоны',
    'tools': 'Инструменты',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
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
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<LynxMarketplaceItem> get _filtered {
    final items = _catalog?.items ?? [];
    final q = _searchCtrl.text.trim().toLowerCase();
    return items.where((m) {
      if (_category != 'all' && m.category != _category) return false;
      if (q.isEmpty) return true;
      if (m.title.toLowerCase().contains(q)) return true;
      if ((m.author ?? '').toLowerCase().contains(q)) return true;
      for (final t in m.tags) {
        if (t.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  Future<void> _onItemTap(LynxMarketplaceItem item) async {
    final label = item.kind == 'template' ? 'Создать проект' : 'Установить';
    await openMarketplaceItemDetail(
      context,
      item: item,
      primaryActionLabel: label,
      onPrimaryAction: () => _runItemAction(item),
    );
  }

  Future<void> _runItemAction(LynxMarketplaceItem item) async {
    if (item.kind == 'template') {
      await _createFromTemplate(item);
      return;
    }
    if (item.kind == 'engine_core') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.description ?? 'Скачайте ядро с Lynx Hub.')),
      );
      return;
    }
    await _installIntoProject(item);
  }

  Future<void> _createFromTemplate(LynxMarketplaceItem item) async {
    final nameCtrl = TextEditingController(text: item.title);
    final dest = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Создать: ${item.title}'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Имя папки проекта'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              final picked = await FilePicker.platform.getDirectoryPath(
                dialogTitle: 'Папка для нового проекта',
              );
              if (picked == null || !ctx.mounted) return;
              Navigator.pop(ctx, p.join(picked, nameCtrl.text.trim()));
            },
            child: const Text('Выбрать папку'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    if (dest == null || dest.isEmpty) return;

    final repoRoot = p.normalize(p.join(Directory.current.path, '..'));
    final result = await LynxMarketplace.createFromTemplateItem(
      item: item,
      destPath: dest,
      repoRoot: repoRoot,
      displayName: item.title,
    );
    if (!mounted) return;
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }
    await rememberLynxLocalProject(
      projectPath: dest,
      projectName: p.basename(dest),
    );
    if (!mounted) return;
    openLynxLocalProjectInEditor(
      context,
      projectPath: dest,
      projectName: p.basename(dest),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  Future<void> _installIntoProject(LynxMarketplaceItem item) async {
    final projectRoot = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Папка проекта Lynx (с project.json)',
    );
    if (projectRoot == null) return;

    final repoRoot = p.normalize(p.join(Directory.current.path, '..'));
    final auth = context.read<AuthProvider>();
    final result = await LynxMarketplace.installIntoProject(
      projectRoot: projectRoot,
      item: item,
      repoRoot: repoRoot,
      cloudDio: auth.isAuthenticated ? auth.http : null,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.ok ? null : Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isHub = cs.primary.value == LynxHubPalette.accent.value;
    final bg = isHub ? LynxHubPalette.bg : cs.surface;
    final filtered = _filtered;
    final games = filtered.where((m) => m.kind == 'game' || m.category == 'games').toList();
    final assets = filtered.where((m) => m.kind != 'game' && m.category != 'games').toList();

    return Scaffold(
      backgroundColor: bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: cs.error))))
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lynx Cloud', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: isHub ? LynxHubPalette.text : cs.onSurface)),
                            const SizedBox(height: 6),
                            Text(
                              'Магазин ассетов, шаблонов и игр от сообщества. Скачивайте, создавайте проекты и публикуйте свои.',
                              style: TextStyle(fontSize: 14, color: isHub ? LynxHubPalette.muted : cs.onSurfaceVariant, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: SearchBar(
                                controller: _searchCtrl,
                                hintText: 'Поиск',
                                leading: const Icon(Icons.search),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loading ? null : _load),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            for (final e in _kCategories.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(e.value),
                                  selected: _category == e.key,
                                  onSelected: (sel) { if (sel) setState(() => _category = e.key); },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (games.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Text('Игры', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isHub ? LynxHubPalette.text : cs.onSurface)),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 290,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            scrollDirection: Axis.horizontal,
                            itemCount: games.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (ctx, i) => LynxXboxTile(
                              title: games[i].title,
                              subtitle: games[i].author,
                              imageUrl: games[i].imageUrl,
                              icon: Icons.sports_esports_outlined,
                              badge: 'ИГРА',
                              onTap: () => _onItemTap(games[i]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Text('Ассеты и шаблоны', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isHub ? LynxHubPalette.text : cs.onSurface)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final list = assets.isEmpty ? filtered : assets;
                            if (i >= list.length) return null;
                            final item = list[i];
                            return LynxXboxTile(
                              title: item.title,
                              subtitle: item.description,
                              imageUrl: item.imageUrl,
                              icon: item.category == '3d' ? Icons.view_in_ar : Icons.extension_outlined,
                              badge: item.kind.toUpperCase(),
                              height: 240,
                              width: double.infinity,
                              onTap: () => _onItemTap(item),
                            );
                          },
                          childCount: (assets.isEmpty ? filtered : assets).length,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
