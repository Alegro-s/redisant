import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../engine/project_manager.dart';
import 'narrative_codec.dart';
import 'narrative_service.dart';
import 'narrative_vn_screen.dart';

/// Opens narrative VN from project `assets/narrative/dialog.json` or demo.
Future<void> openProjectNarrativePreview(BuildContext context, {String? projectRoot}) async {
  final root = projectRoot ?? context.read<ProjectManager>().rootPath;
  NarrativeScript? script;
  if (root != null && root.isNotEmpty) {
    script = await NarrativeService(root).load();
  }
  script ??= NarrativeService.demoScript();
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => NarrativeVnScreen(script: script!)),
  );
}

/// Launcher narrative demo route (wave 28).
class NarrativePreviewScreen extends StatelessWidget {
  const NarrativePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Narrative')),
      body: Center(
        child: FilledButton.icon(
          onPressed: () => openProjectNarrativePreview(context),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Запустить VN preview'),
        ),
      ),
    );
  }
}
