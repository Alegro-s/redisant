import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';
import '../auth/providers/auth_provider.dart';
import '../ecosystem/lynx_marketplace_billing.dart';

/// Creator dashboard + billing (wave 30 production UI).
class MarketplaceCreatorDashboardScreen extends StatefulWidget {
  const MarketplaceCreatorDashboardScreen({super.key});

  @override
  State<MarketplaceCreatorDashboardScreen> createState() =>
      _MarketplaceCreatorDashboardScreenState();
}

class _MarketplaceCreatorDashboardScreenState extends State<MarketplaceCreatorDashboardScreen> {
  LynxCreatorDashboard? _dash;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final base = context.read<SettingsProvider>().marketplaceApiBase.trim();
    final billing = LynxMarketplaceBilling(
      apiBase: base.isNotEmpty ? base : null,
      dio: auth.isAuthenticated ? auth.http : null,
    );
    final id = auth.user?.id ?? 'demo';
    final dash = await billing.fetchCreatorDashboard(id);
    if (mounted) {
      setState(() {
        _dash = dash;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Creator: ${_dash?.creatorId ?? "—"}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  _StatCard(label: 'Продажи', value: '${_dash?.totalSales ?? 0}'),
                  _StatCard(label: 'На модерации', value: '${_dash?.pendingReview ?? 0}'),
                  const SizedBox(height: 8),
                  Text('Опубликованные cart', style: Theme.of(context).textTheme.titleSmall),
                  ...(_dash?.publishedCarts ?? const []).map((c) => ListTile(title: Text(c))),
                  const Spacer(),
                  FilledButton(
                    onPressed: () async {
                      final billing = LynxMarketplaceBilling(
                        apiBase: context.read<SettingsProvider>().marketplaceApiBase,
                        dio: context.read<AuthProvider>().http,
                      );
                      final r = await billing.purchaseCart(
                        cartId: 'demo_cart',
                        buyerUserId: context.read<AuthProvider>().user?.id ?? 'guest',
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            r.success
                                ? 'Покупка OK: ${r.transactionId}'
                                : (r.error ?? 'Ошибка'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Тест покупки cart (billing API)'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(label), trailing: Text(value, style: const TextStyle(fontSize: 20))),
    );
  }
}
