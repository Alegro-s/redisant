import 'package:flutter/material.dart';

import '../models/engine_models.dart';
import '../runtime/scene_ui_codec.dart';
import '../../game/game_ui_overlay.dart';

/// Превью UI с aspect 16:9 / 9:16 (волна 10d).
class UiLayoutPreviewPanel extends StatefulWidget {
  final SceneObject object;
  final double baseDesignW;
  final double baseDesignH;

  const UiLayoutPreviewPanel({
    super.key,
    required this.object,
    this.baseDesignW = 1280,
    this.baseDesignH = 720,
  });

  @override
  State<UiLayoutPreviewPanel> createState() => _UiLayoutPreviewPanelState();
}

class _UiLayoutPreviewPanelState extends State<UiLayoutPreviewPanel> {
  bool _portrait = false;

  @override
  Widget build(BuildContext context) {
    final dw = _portrait ? 720.0 : widget.baseDesignW;
    final dh = _portrait ? 1280.0 : widget.baseDesignH;
    final scene = Scene(
      id: 'preview',
      name: 'Preview',
      objects: [widget.object],
      createdAt: DateTime.now().toUtc(),
      modifiedAt: DateTime.now().toUtc(),
    );
    final widgets = buildUiWidgetsFromScene(scene, designWidth: dw, designHeight: dh);
    final aspect = _portrait ? 9 / 16 : 16 / 9;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('16:9')),
            ButtonSegment(value: true, label: Text('9:16')),
          ],
          selected: {_portrait},
          onSelectionChanged: (s) => setState(() => _portrait = s.first),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: aspect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0d1117),
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final vw = constraints.maxWidth;
                final vh = constraints.maxHeight;
                return GameUiOverlay(
                  widgets: widgets,
                  viewWidth: vw,
                  viewHeight: vh,
                  cameraX: dw / 2,
                  cameraY: dh / 2,
                  paintZoom: vw / dw,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
