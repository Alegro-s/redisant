import 'package:client/features/engine/runtime/animation_player_codec.dart';
import 'package:client/features/engine/runtime/scene_ui_codec.dart';
import 'package:client/features/engine/models/engine_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ui anchor bottom places button low on tall canvas', () {
    final scene = Scene(
      id: 's',
      name: 'S',
      objects: [
        SceneObject(
          id: 'btn',
          name: 'Start',
          assetId: '',
          x: 0,
          y: 0,
          layerId: SceneLayer.uiLayerId,
          width: 200,
          height: 40,
          properties: defaultUiButtonAnchoredProperties('Go', 'load_scene:main'),
        ),
      ],
      createdAt: DateTime.now().toUtc(),
      modifiedAt: DateTime.now().toUtc(),
    );
    final wide = buildUiWidgetsFromScene(scene, designWidth: 1280, designHeight: 720);
    final tall = buildUiWidgetsFromScene(scene, designWidth: 720, designHeight: 1280);
    final yWide = (wide.first['y'] as num).toDouble();
    final yTall = (tall.first['y'] as num).toDouble();
    expect(yWide, greaterThan(500));
    expect(yTall, greaterThan(yWide));
  });

  test('clip events still parse after wave9', () {
    final timelines = clipsTimelinesFromProperties({
      'rustAnimationClips': {
        'run': {
          'frames': [{'x': 0, 'y': 0, 'w': 1, 'h': 1}],
          'fps': 8,
          'events': [{'frame': 0, 'type': 'signal', 'name': 'ping'}],
        },
      },
    });
    expect(timelines['run']!.events.first.name, 'ping');
  });
}
