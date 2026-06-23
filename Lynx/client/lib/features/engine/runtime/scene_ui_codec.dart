import '../models/engine_models.dart';

/// UI-виджеты сцены для Play (волна 5c → 10c layout v2).
List<Map<String, dynamic>> buildUiWidgetsFromScene(
  Scene scene, {
  double? designWidth,
  double? designHeight,
}) {
  final dw = designWidth ?? 1280.0;
  final dh = designHeight ?? 720.0;
  final out = <Map<String, dynamic>>[];
  for (final o in scene.objects) {
    if (!o.active || !o.visible) continue;
    final ui = o.properties['lynxUi'];
    final onUiLayer = o.layerId == SceneLayer.uiLayerId;
    if (ui is! Map && !onUiLayer) continue;
    final map = ui is Map ? Map<String, dynamic>.from(ui) : <String, dynamic>{};
    final resolved = resolveLynxUiRect(
      x: o.x,
      y: o.y,
      width: o.width <= 0 ? 160.0 : o.width,
      height: o.height <= 0 ? 40.0 : o.height,
      ui: map,
      designW: dw,
      designH: dh,
    );
    out.add({
      'id': o.id,
      'x': resolved.centerX,
      'y': resolved.centerY,
      'w': resolved.width,
      'h': resolved.height,
      'type': map['type'] ?? (onUiLayer ? 'label' : 'label'),
      'text': map['text'] ?? o.name,
      if (map['action'] != null) 'action': map['action'],
      if (map['theme'] != null) 'theme': map['theme'],
      'anchorH': map['anchorH'] ?? 'center',
      'anchorV': map['anchorV'] ?? 'center',
    });
  }
  return out;
}

class UiResolvedRect {
  final double centerX;
  final double centerY;
  final double width;
  final double height;
  const UiResolvedRect({
    required this.centerX,
    required this.centerY,
    required this.width,
    required this.height,
  });
}

/// Якоря + margin относительно design resolution (волна 10c).
UiResolvedRect resolveLynxUiRect({
  required double x,
  required double y,
  required double width,
  required double height,
  required Map<String, dynamic> ui,
  required double designW,
  required double designH,
}) {
  final anchorH = ui['anchorH'] as String? ?? 'center';
  final anchorV = ui['anchorV'] as String? ?? 'center';
  final margin = ui['margin'] is Map
      ? Map<String, dynamic>.from(ui['margin'] as Map)
      : <String, dynamic>{};
  final ml = (margin['l'] as num?)?.toDouble() ?? 0;
  final mt = (margin['t'] as num?)?.toDouble() ?? 0;
  final mr = (margin['r'] as num?)?.toDouble() ?? 0;
  final mb = (margin['b'] as num?)?.toDouble() ?? 0;

  double cx = x;
  double cy = y;
  if (anchorH == 'left') {
    cx = ml + width / 2;
  } else if (anchorH == 'right') {
    cx = designW - mr - width / 2;
  } else if (anchorH == 'stretch') {
    cx = (ml + designW - mr) / 2;
  } else if (anchorH == 'center' && (ml > 0 || mr > 0)) {
    cx = designW / 2 + (ml - mr) / 2;
  }

  if (anchorV == 'top') {
    cy = mt + height / 2;
  } else if (anchorV == 'bottom') {
    cy = designH - mb - height / 2;
  } else if (anchorV == 'stretch') {
    cy = (mt + designH - mb) / 2;
  } else if (anchorV == 'center' && (mt > 0 || mb > 0)) {
    cy = designH / 2 + (mt - mb) / 2;
  }

  final w = anchorH == 'stretch'
      ? (designW - ml - mr).clamp(32.0, designW).toDouble()
      : width;
  final h = anchorV == 'stretch'
      ? (designH - mt - mb).clamp(24.0, designH).toDouble()
      : height;

  return UiResolvedRect(centerX: cx, centerY: cy, width: w, height: h);
}

Map<String, dynamic> defaultUiLabelProperties(String text) => {
      'lynxUi': {'type': 'label', 'text': text},
    };

Map<String, dynamic> defaultUiButtonProperties(String text, String action) => {
      'lynxUi': {'type': 'button', 'text': text, 'action': action},
    };

/// Кнопка с якорем внизу по центру (адаптив 16:9 / 9:16).
Map<String, dynamic> defaultUiButtonAnchoredProperties(
  String text,
  String action, {
  String anchorH = 'center',
  String anchorV = 'bottom',
  double marginBottom = 32,
}) =>
    {
      'lynxUi': {
        'type': 'button',
        'text': text,
        'action': action,
        'anchorH': anchorH,
        'anchorV': anchorV,
        'margin': {'l': 16, 't': 16, 'r': 16, 'b': marginBottom},
        'theme': 'dark',
      },
    };
