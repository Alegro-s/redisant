import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';

class AssetStoreCatalogScreen extends StatefulWidget {
  const AssetStoreCatalogScreen({super.key});

  @override
  State<AssetStoreCatalogScreen> createState() => _AssetStoreCatalogScreenState();
}

class _AssetStoreCatalogScreenState extends State<AssetStoreCatalogScreen> {
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = false;
  final _searchCtrl = TextEditingController();
  String _category = 'all';

  static const _kCategories = <String, String>{
    'all': 'Все',
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
    final url = context.read<SettingsProvider>().storeCatalogUrl.trim();
    if (url.isEmpty) {
      setState(() => _items = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final r = await dio.get<dynamic>(url);
      final data = r.data;
      final list = <Map<String, dynamic>>[];
      if (data is Map && data['items'] is List) {
        for (final e in data['items'] as List) {
          if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      } else if (data is List) {
        for (final e in data) {
          if (e is Map) {
            list.add(Map<String, dynamic>.from(e));
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _items = list;
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

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _items.where((m) {
      final cat = (m['category']?.toString() ?? 'all').toLowerCase();
      if (_category != 'all' && cat != _category) return false;
      if (q.isEmpty) return true;
      final title = (m['title']?.toString() ?? '').toLowerCase();
      final author = (m['author']?.toString() ?? '').toLowerCase();
      final tags = m['tags'];
      var tagHit = false;
      if (tags is List) {
        for (final t in tags) {
          if (t.toString().toLowerCase().contains(q)) {
            tagHit = true;
            break;
          }
        }
      }
      return title.contains(q) || author.contains(q) || tagHit;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final url = context.watch<SettingsProvider>().storeCatalogUrl.trim();
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lynx Cloud'),
            Text(
              'каталог ассетов',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: url.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Укажите URL каталога (JSON: { "items": [ { "title", "author", "price", '
                  '"category", "rating", "image" } ] }) в «Профиль» → «Lynx Launcher и Editor». '
                  'Категории: 2d, audio, templates, tools.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          style: TextStyle(color: cs.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SearchBar(
                                  controller: _searchCtrl,
                                  hintText: 'Поиск по названию, автору, тегам',
                                  leading: const Icon(Icons.search),
                                  trailing: [
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final e in _kCategories.entries)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: FilterChip(
                                            label: Text(e.value),
                                            selected: _category == e.key,
                                            onSelected: (sel) {
                                              if (sel) setState(() => _category = e.key);
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (filtered.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            sliver: SliverToBoxAdapter(
                              child: Text(
                                'Рекомендуем',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final w = constraints.crossAxisExtent;
                              final cols = w >= 900
                                  ? 3
                                  : w >= 560
                                      ? 2
                                      : 1;
                              final gap = 14.0;
                              final tileW = (w - gap * (cols - 1)) / cols;
                              return SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisSpacing: gap,
                                  crossAxisSpacing: gap,
                                  childAspectRatio: tileW / 268,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, i) {
                                    if (i >= filtered.length) return null;
                                    return _StoreAssetCard(item: filtered[i]);
                                  },
                                  childCount: filtered.length,
                                ),
                              );
                            },
                          ),
                        ),
                        if (filtered.isEmpty && _items.isNotEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text('Ничего не найдено — смените фильтр или запрос.')),
                          ),
                        if (_items.isEmpty && !_loading)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(child: Text('Каталог пуст. Проверьте JSON.')),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
    );
  }
}

class _StoreAssetCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _StoreAssetCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = item['title']?.toString() ?? 'Без названия';
    final author = item['author']?.toString() ?? '';
    final price = item['price'];
    final rating = (item['rating'] as num?)?.toDouble();
    final imageUrl = item['image']?.toString() ?? item['thumbnail']?.toString();

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('«$title» — покупка и загрузка появятся в следующих релизах.')),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(cs),
                    )
                  : _placeholder(cs),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(Icons.star_rounded, size: 16, color: cs.primary),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      if (price != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '₽$price',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.image_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
      ),
    );
  }
}
