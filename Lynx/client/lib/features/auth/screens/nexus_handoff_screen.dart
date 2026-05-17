import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class NexusHandoffScreen extends StatefulWidget {
  const NexusHandoffScreen({
    super.key,
    required this.challengeId,
    required this.sessionToken,
    this.apiBase,
  });

  final String challengeId;
  final String sessionToken;
  final String? apiBase;

  @override
  State<NexusHandoffScreen> createState() => _NexusHandoffScreenState();
}

class _NexusHandoffScreenState extends State<NexusHandoffScreen> {
  String? _code;
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
      _code = null;
    });

    if (widget.challengeId.isEmpty || widget.sessionToken.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Некорректная ссылка: нет challenge_id или session_token.';
      });
      return;
    }

    final auth = context.read<AuthProvider>();
    var base = (widget.apiBase?.trim().isNotEmpty == true)
        ? widget.apiBase!.trim()
        : auth.dioBaseUrl;
    base = base.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Не указан адрес API (api_base в ссылке).';
      });
      return;
    }

    await auth.setApiBaseUrl(base);

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 15),
        ),
      );
      final res = await dio.get<Map<String, dynamic>>(
        '/auth/challenge/nexus-code',
        queryParameters: {
          'challenge_id': widget.challengeId,
          'session_token': widget.sessionToken,
        },
      );
      final c = res.data?['code']?.toString() ?? '';
      if (c.length != 6 || !RegExp(r'^\d{6}$').hasMatch(c)) {
        setState(() {
          _loading = false;
          _error = 'Сервер не вернул код. Проверьте сеть и повторите вход с сайта.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _code = c;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error =
            'Не удалось получить код. Убедитесь, что телефон в сети и API доступен по $base';
      });
    }
  }

  Future<void> _copy() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _code!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код скопирован — вставьте на сайте Метрики')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход через Метрику'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Подтверждение из веб-консоли',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Сайт «Метрика» запросил одноразовый код. Он показан ниже — введите его в браузере, чтобы завершить вход.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error, height: 1.4))
              else if (_code != null) ...[
                Material(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                    child: Center(
                      child: Text(
                        _code!,
                        style: theme.textTheme.displayMedium?.copyWith(
                          letterSpacing: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Скопировать код'),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Закрыть и перейти ко входу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
