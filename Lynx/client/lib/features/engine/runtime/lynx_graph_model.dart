/// LynxGraph — visual Blueprint model (JSON) compiled to LynxScript text.

class LynxGraphDocument {
  LynxGraphDocument({required this.statements});

  final List<LynxGraphStatement> statements;

  Map<String, dynamic> toJson() => {
        'format': 'lynxgraph',
        'schema': 1,
        'statements': statements.map((s) => s.toJson()).toList(),
      };

  factory LynxGraphDocument.fromJson(Map<String, dynamic> json) {
    final raw = json['statements'];
    final list = <LynxGraphStatement>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(LynxGraphStatement.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return LynxGraphDocument(statements: list);
  }

  static LynxGraphDocument defaultPlayerController() => LynxGraphDocument(
        statements: [
          LynxGraphStatement.setVelocity('0', 'vy'),
          LynxGraphStatement.ifCond('key_a', [
            LynxGraphStatement.setVelocity('-260', 'vy'),
          ]),
          LynxGraphStatement.ifCond('key_d', [
            LynxGraphStatement.setVelocity('260', 'vy'),
          ]),
          LynxGraphStatement.ifCond('action_pressed', [
            LynxGraphStatement.ifCond('on_ground', [
              LynxGraphStatement.setVelocity('vx', '-520'),
            ]),
          ], actionName: 'jump'),
        ],
      );
}

class LynxGraphStatement {
  LynxGraphStatement({
    required this.type,
    this.vx,
    this.vy,
    this.cond,
    this.actionName,
    this.children = const [],
  });

  final String type;
  final String? vx;
  final String? vy;
  final String? cond;
  final String? actionName;
  final List<LynxGraphStatement> children;

  factory LynxGraphStatement.setVelocity(String vx, String vy) => LynxGraphStatement(
        type: 'set_velocity',
        vx: vx,
        vy: vy,
      );

  factory LynxGraphStatement.ifCond(
    String cond,
    List<LynxGraphStatement> children, {
    String? actionName,
  }) =>
      LynxGraphStatement(
        type: 'if',
        cond: cond,
        actionName: actionName,
        children: children,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        if (vx != null) 'vx': vx,
        if (vy != null) 'vy': vy,
        if (cond != null) 'cond': cond,
        if (actionName != null) 'action': actionName,
        if (children.isNotEmpty)
          'then': children.map((c) => c.toJson()).toList(),
      };

  factory LynxGraphStatement.fromJson(Map<String, dynamic> json) {
    final thenRaw = json['then'];
    final kids = <LynxGraphStatement>[];
    if (thenRaw is List) {
      for (final t in thenRaw) {
        if (t is Map) {
          kids.add(LynxGraphStatement.fromJson(t.cast<String, dynamic>()));
        }
      }
    }
    return LynxGraphStatement(
      type: json['type']?.toString() ?? 'noop',
      vx: json['vx']?.toString(),
      vy: json['vy']?.toString(),
      cond: json['cond']?.toString(),
      actionName: json['action']?.toString(),
      children: kids,
    );
  }
}
