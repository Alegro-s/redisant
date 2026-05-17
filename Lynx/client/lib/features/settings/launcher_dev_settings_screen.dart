import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/providers/settings_provider.dart';

class LauncherDevSettingsScreen extends StatefulWidget {
  const LauncherDevSettingsScreen({super.key});

  @override
  State<LauncherDevSettingsScreen> createState() => _LauncherDevSettingsScreenState();
}

class _LauncherDevSettingsScreenState extends State<LauncherDevSettingsScreen> {
  late TextEditingController _exe;
  late TextEditingController _news;
  late TextEditingController _store;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsProvider>();
    _exe = TextEditingController(text: s.nexusEditorExecutablePath);
    _news = TextEditingController(text: s.newsFeedUrl);
    _store = TextEditingController(text: s.storeCatalogUrl);
  }

  @override
  void dispose() {
    _exe.dispose();
    _news.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Lynx Launcher и Editor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Lynx Launcher — это это приложение. Lynx Editor собирается отдельно:\n'
            '`flutter build windows -t lib/main_editor.dart`',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (!kIsWeb) ...[
            SwitchListTile(
              title: const Text('Открывать редактор отдельным процессом'),
              subtitle: const Text('На desktop: вместо встроенного /engine запускается exe Lynx Editor.'),
              value: settings.launchEditorSeparate,
              onChanged: (v) => settings.setLaunchEditorSeparate(v),
            ),
            TextField(
              controller: _exe,
              decoration: const InputDecoration(
                labelText: 'Путь к Lynx Editor (exe/AppImage/app)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => settings.setNexusEditorExecutablePath(_exe.text),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => settings.setNexusEditorExecutablePath(_exe.text),
              child: const Text('Сохранить путь'),
            ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _news,
            decoration: const InputDecoration(
              labelText: 'URL RSS / Atom ленты новостей',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => settings.setNewsFeedUrl(_news.text),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => settings.setNewsFeedUrl(_news.text),
            child: const Text('Сохранить URL новостей'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _store,
            decoration: const InputDecoration(
              labelText: 'URL JSON каталога магазина',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => settings.setStoreCatalogUrl(_store.text),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => settings.setStoreCatalogUrl(_store.text),
            child: const Text('Сохранить URL магазина'),
          ),
        ],
      ),
    );
  }
}
