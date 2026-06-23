/// JSON dialog graph for in-engine VN (Ren-ось).
class NarrativeDialogNode {
  final String id;
  final String speaker;
  final String text;
  final List<NarrativeChoice> choices;
  final String? nextId;

  const NarrativeDialogNode({
    required this.id,
    required this.speaker,
    required this.text,
    this.choices = const [],
    this.nextId,
  });

  factory NarrativeDialogNode.fromJson(Map<String, dynamic> j) => NarrativeDialogNode(
        id: j['id'] as String? ?? '',
        speaker: j['speaker'] as String? ?? '',
        text: j['text'] as String? ?? '',
        choices: (j['choices'] as List?)
                ?.map((e) => NarrativeChoice.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
        nextId: j['next'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'speaker': speaker,
        'text': text,
        if (choices.isNotEmpty) 'choices': choices.map((c) => c.toJson()).toList(),
        if (nextId != null) 'next': nextId,
      };
}

class NarrativeChoice {
  final String label;
  final String gotoId;
  final String? condition;

  const NarrativeChoice({required this.label, required this.gotoId, this.condition});

  factory NarrativeChoice.fromJson(Map<String, dynamic> j) => NarrativeChoice(
        label: j['label'] as String? ?? '',
        gotoId: j['goto'] as String? ?? '',
        condition: j['condition'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'goto': gotoId,
        if (condition != null) 'condition': condition,
      };
}

class NarrativeScript {
  final String startId;
  final Map<String, NarrativeDialogNode> nodes;

  const NarrativeScript({required this.startId, required this.nodes});

  factory NarrativeScript.fromJson(Map<String, dynamic> j) {
    final start = j['start'] as String? ?? 'start';
    final raw = j['nodes'] as Map? ?? {};
    final nodes = <String, NarrativeDialogNode>{};
    for (final e in raw.entries) {
      if (e.value is Map) {
        nodes[e.key.toString()] =
            NarrativeDialogNode.fromJson(Map<String, dynamic>.from(e.value as Map));
      }
    }
    return NarrativeScript(startId: start, nodes: nodes);
  }

  NarrativeDialogNode? node(String id) => nodes[id];
}
