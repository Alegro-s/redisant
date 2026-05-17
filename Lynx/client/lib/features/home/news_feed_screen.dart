import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';

import '../../app/providers/settings_provider.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedItem {
  _NewsFeedItem({required this.title, required this.link});
  final String title;
  final String link;
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  List<_NewsFeedItem>? _items;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final url = context.read<SettingsProvider>().newsFeedUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _items = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final r = await dio.get<String>(url, options: Options(responseType: ResponseType.plain));
      final body = r.data ?? '';
      final doc = XmlDocument.parse(body);
      final out = <_NewsFeedItem>[];
      for (final item in doc.findAllElements('item')) {
        final t = item.getElement('title')?.innerText.trim() ?? '';
        final l = item.getElement('link')?.innerText.trim() ?? '';
        if (t.isEmpty) continue;
        out.add(_NewsFeedItem(title: t, link: l));
      }
      if (out.isEmpty) {
        for (final entry in doc.findAllElements('entry')) {
          final t = entry.getElement('title')?.innerText.trim() ?? '';
          var l = entry.getElement('link')?.innerText.trim() ?? '';
          if (l.isEmpty) {
            final ln = entry.getElement('link');
            l = ln?.getAttribute('href') ?? '';
          }
          if (t.isEmpty) continue;
          out.add(_NewsFeedItem(title: t, link: l));
        }
      }
      if (!mounted) return;
      setState(() {
        _items = out;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
        _items = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = context.watch<SettingsProvider>().newsFeedUrl.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новости'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: url.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Укажите URL RSS в «Профиль» → «Lynx Launcher и Editor».',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items?.length ?? 0,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final it = _items![i];
                return ListTile(
                  title: Text(it.title),
                  trailing: it.link.isNotEmpty ? const Icon(Icons.open_in_new, size: 18) : null,
                  onTap: it.link.isEmpty
                      ? null
                      : () async {
                          final u = Uri.tryParse(it.link);
                          if (u != null && await canLaunchUrl(u)) {
                            await launchUrl(u, mode: LaunchMode.externalApplication);
                          }
                        },
                );
              },
            ),
    );
  }
}
