import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';
import '../auth/providers/auth_provider.dart';
import 'live_ops_config_service.dart';
import 'live_ops_leaderboard_service.dart';

/// Live Ops hub: remote config + leaderboards (wave 29 production UI).
class LiveOpsHubScreen extends StatefulWidget {
  const LiveOpsHubScreen({super.key});

  @override
  State<LiveOpsHubScreen> createState() => _LiveOpsHubScreenState();
}

class _LiveOpsHubScreenState extends State<LiveOpsHubScreen> {
  LiveOpsConfigService? _config;
  List<LiveOpsLeaderboardEntry> _top = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final settings = context.read<SettingsProvider>();
    _config = LiveOpsConfigService(
      configUrl: settings.liveOpsConfigUrl.trim().isNotEmpty
          ? settings.liveOpsConfigUrl.trim()
          : null,
    );
    final lb = LiveOpsLeaderboardService(
      apiBase: settings.leaderboardApiUrl.trim().isNotEmpty
          ? settings.leaderboardApiUrl.trim()
          : null,
    );
    try {
      await _config!.refresh();
      final top = await lb.fetchTop();
      if (!mounted) return;
      setState(() {
        _top = top;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Ops'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Text('Remote config', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_config == null || _config!.values.isEmpty)
                  const Text('Нет данных — задайте URL в Настройки → Live Ops config JSON.')
                else
                  ..._config!.values.entries.map(
                    (e) => ListTile(
                      dense: true,
                      title: Text(e.key),
                      subtitle: Text('${e.value}'),
                    ),
                  ),
                const Divider(height: 32),
                Text('Лидерборд', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final e in _top)
                  ListTile(
                    leading: CircleAvatar(child: Text('${e.rank}')),
                    title: Text(e.displayName),
                    subtitle: Text('ID: ${e.playerId}'),
                    trailing: Text('${e.score}'),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: auth.isAuthenticated && auth.user != null
                      ? () async {
                          final ok = await LiveOpsLeaderboardService(
                            apiBase: context.read<SettingsProvider>().leaderboardApiUrl,
                          ).submitScore(
                            boardId: 'default',
                            playerId: auth.user!.id,
                            score: DateTime.now().millisecondsSinceEpoch % 10000,
                            authToken: auth.token,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'Счёт отправлен' : 'Ошибка отправки')),
                          );
                          await _load();
                        }
                      : null,
                  icon: const Icon(Icons.upload),
                  label: const Text('Отправить demo-счёт'),
                ),
              ],
            ),
    );
  }
}
