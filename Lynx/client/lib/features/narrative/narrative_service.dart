import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'narrative_codec.dart';

/// Load/save `assets/narrative/dialog.json` in project.
class NarrativeService {
  NarrativeService(this.projectRoot);
  final String projectRoot;

  Future<NarrativeScript?> load() async {
    final f = File(p.join(projectRoot, 'assets', 'narrative', 'dialog.json'));
    if (!await f.exists()) return null;
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return NarrativeScript.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(NarrativeScript script) async {
    final dir = Directory(p.join(projectRoot, 'assets', 'narrative'));
    await dir.create(recursive: true);
    final payload = {
      'start': script.startId,
      'nodes': {for (final e in script.nodes.entries) e.key: e.value.toJson()},
    };
    await File(p.join(dir.path, 'dialog.json')).writeAsString(jsonEncode(payload));
  }

  static NarrativeScript demoScript() => NarrativeScript.fromJson({
        'start': 'intro',
        'nodes': {
          'intro': {
            'id': 'intro',
            'speaker': 'Guide',
            'text': 'Добро пожаловать в Lynx Narrative.',
            'next': 'choice1',
          },
          'choice1': {
            'id': 'choice1',
            'speaker': 'Guide',
            'text': 'Куда пойдём?',
            'choices': [
              {'label': 'В Engine', 'goto': 'engine'},
              {'label': 'В Arcade', 'goto': 'arcade'},
            ],
          },
          'engine': {
            'id': 'engine',
            'speaker': 'Guide',
            'text': 'Отлично — откройте проект и Play.',
          },
          'arcade': {
            'id': 'arcade',
            'speaker': 'Guide',
            'text': 'Каталог free-to-play в Launcher → Аркада.',
          },
        },
      });
}
