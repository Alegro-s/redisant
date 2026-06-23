import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart';

import '../../app/providers/settings_provider.dart';
import 'lynx_hub_content_service.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  List<LynxHubNewsItem> _hubNews = const [];
  List<_RssItem> _rssItems = const [];
  String? _error;
  bool _loading = false;

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
    try {
      final hubUrl = settings.hubContentUrl.trim().isNotEmpty
          ? settings.hubContentUrl.trim()
          : LynxHubContentService.defaultHubContentUrl;
      final hub = await LynxHubContentService.fetchNews(contentUrl: hubUrl);
      var rss = <_RssItem>[];
      final rssUrl = settings.newsFeedUrl.trim();
      if (rssUrl.isNotEmpty) {
        rss = await _loadRss(rssUrl);
      }
      if (!mounted) return;
      setState(() {
        _hubNews = hub;
        _rssItems = rss;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final code = e.response?.statusCode;
      setState(() {
        _loading = false;
        _error = code == 429
            ? 'Слишком много запросов. Подождите минуту и обновите.'
            : 'Не удалось загрузить новости ($code).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить новости.';
      });
    }
  }

  Future<List<_RssItem>> _loadRss(String url) async {
    final dio = Dio();
    final r = await dio.get<String>(url, options: Options(responseType: ResponseType.plain));
    final doc = XmlDocument.parse(r.data ?? '');
    final out = <_RssItem>[];
    for (final item in doc.findAllElements('item')) {
      final t = item.getElement('title')?.innerText.trim() ?? '';
      final l = item.getElement('link')?.innerText.trim() ?? '';
      if (t.isNotEmpty) out.add(_RssItem(title: t, link: l));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final items = [
      ..._hubNews.map((n) => _NewsRow(
        title: n.title,
        subtitle: n.date,
        body: n.body,
        link: 'https://lynx.app/blog#${n.slug}',
      )),
      ..._rssItems.map((n) => _NewsRow(title: n.title, subtitle: '', body: '', link: n.link)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новости'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: cs.error))))
          : items.isEmpty
          ? const Center(child: Text('Новостей пока нет'))
          : ListView.separated(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => SizedBox(height: isMobile ? 10 : 14),
              itemBuilder: (context, i) => _NewsCard(row: items[i], compact: isMobile),
            ),
    );
  }
}

class _RssItem {
  final String title;
  final String link;
  const _RssItem({required this.title, required this.link});
}

class _NewsRow {
  final String title;
  final String subtitle;
  final String body;
  final String link;
  const _NewsRow({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.link,
  });
}

class _NewsCard extends StatelessWidget {
  final _NewsRow row;
  final bool compact;
  const _NewsCard({required this.row, required this.compact});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(compact ? 12 : 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        onTap: row.link.isEmpty
            ? null
            : () async {
                final u = Uri.tryParse(row.link);
                if (u != null && await canLaunchUrl(u)) {
                  await launchUrl(u, mode: LaunchMode.externalApplication);
                }
              },
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row.subtitle.isNotEmpty)
                Text(row.subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              Text(row.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 14 : 16, color: cs.onSurface)),
              if (row.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  row.body,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
