import 'package:flutter/material.dart';

import 'narrative_codec.dart';

/// Full-screen VN player for narrative scripts (wave 28).
class NarrativeVnScreen extends StatefulWidget {
  const NarrativeVnScreen({super.key, required this.script});

  final NarrativeScript script;

  @override
  State<NarrativeVnScreen> createState() => _NarrativeVnScreenState();
}

class _NarrativeVnScreenState extends State<NarrativeVnScreen> {
  late String _currentId;

  @override
  void initState() {
    super.initState();
    _currentId = widget.script.startId;
  }

  void _goto(String id) => setState(() => _currentId = id);

  @override
  Widget build(BuildContext context) {
    final node = widget.script.node(_currentId);
    if (node == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Narrative')),
        body: const Center(child: Text('Узел не найден')),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text(node.speaker.isEmpty ? 'Narrative' : node.speaker),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(node.text, style: Theme.of(context).textTheme.bodyLarge),
            ),
            if (node.choices.isNotEmpty)
              ...node.choices.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _goto(c.gotoId),
                      child: Text(c.label),
                    ),
                  ),
                ),
              )
            else if (node.nextId != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => _goto(node.nextId!),
                  child: const Text('Далее'),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
