import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';
import '../auth/providers/auth_provider.dart';
import 'arcade_local_resolver.dart';
import 'arcade_catalog_service.dart';

/// Вкладка «Аркада» в Launcher (волна 18).
class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({super.key});

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen> {
  List<ArcadeGameEntry> _games = [];
  List<ArcadeGameEntry> _filtered = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final settings = context.read<SettingsProvider>();
    final games = await ArcadeCatalogService(dio: auth.http).loadFreeToPlay(
      catalogUrl: settings.storeCatalogUrl.isNotEmpty ? settings.storeCatalogUrl : null,
      apiBase: auth.dioBaseUrl,
    );
    if (!mounted) return;
    setState(() {
      _games = games;
      _filtered = games;
      _loading = false;
    });
  }

  void _applyFilter(String q) {
    _query = q.trim().toLowerCase();
    if (_query.isEmpty) {
      _filtered = _games;
    } else {
      _filtered = _games.where((g) {
        if (g.title.toLowerCase().contains(_query)) return true;
        if (g.description.toLowerCase().contains(_query)) return true;
        return g.tags.any((t) => t.toLowerCase().contains(_query));
      }).toList();
    }
    setState(() {});
  }

  Future<void> _play(ArcadeGameEntry game) async {
    if (!kIsWeb) {
      final localCart = await ArcadeLocalResolver.resolveBundledCartFile(game.id);
      if (localCart != null) {
        if (!context.mounted) return;
        context.push(
          '/play-cart',
          extra: {'cartId': game.id, 'cartPath': localCart},
        );
        return;
      }
      final tpl = game.projectTemplate ?? ArcadeLocalResolver.templateIdForCart(game.id);
      if (tpl != null) {
        final root = await ArcadeLocalResolver.resolveBundledTemplateProject(tpl);
        if (root != null) {
          if (!context.mounted) return;
          context.push('/play', extra: {'projectPath': root, 'freshPlay': true});
          return;
        }
      }
    }
    if (kIsWeb) {
      context.push('/play-cart?cartId=${Uri.encodeComponent(game.id)}');
      return;
    }
    context.push(
      '/play-cart',
      extra: {'cartId': game.id, 'cartPath': game.cartUrl},
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Аркада', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Free-to-play каталог — играй без установки Engine (Web) или из cart.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SearchBar(
                    hintText: 'Поиск по названию и тегам',
                    onChanged: _applyFilter,
                    leading: const Icon(Icons.search),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('Нет игр в каталоге')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final g = _filtered[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _play(g),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.sports_esports, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      g.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  g.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                                ),
                              ),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final t in g.tags.take(4))
                                    Chip(
                                      label: Text(t, style: const TextStyle(fontSize: 11)),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () => _play(g),
                                icon: const Icon(Icons.play_arrow, size: 18),
                                label: const Text('Играть'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _filtered.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
