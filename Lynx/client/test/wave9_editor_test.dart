import 'package:client/features/engine/runtime/animation_player_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clip timeline roundtrip with key events', () {
    final props = <String, dynamic>{
      'rustAnimationClips': {
        'run': {
          'frames': [
            {'x': 0, 'y': 0, 'w': 32, 'h': 32},
            {'x': 32, 'y': 0, 'w': 32, 'h': 32},
          ],
          'fps': 10,
          'events': [
            {'frame': 1, 'type': 'signal', 'name': 'footstep'},
          ],
        },
      },
      'rustAnimStateMachine': {
        'enabled': true,
        'fallback_clip': 'idle',
        'rules': [],
      },
    };
    final timelines = clipsTimelinesFromProperties(props);
    expect(timelines['run']!.events.length, 1);
    expect(timelines['run']!.events.first.name, 'footstep');
    final out = timelinesToClipsJson(timelines);
    final ev = (out['run'] as Map)['events'] as List;
    expect(ev.length, 1);
  });

  test('blend preview lines', () {
    final lines = blendPreviewLines({
      'enabled': true,
      'fallback_clip': 'idle',
      'rules': [
        {'clip_id': 'run', 'conditions': ['speed_x_above'], 'speed_threshold': 20},
      ],
    });
    expect(lines.first, contains('idle'));
    expect(lines.length, greaterThan(1));
  });

  test('platformer demo scene has run clip events', () async {
    // Inline snippet matching platformer-demo export shape.
    final clips = {
      'run': {
        'frames': [
          {'x': 0, 'y': 0, 'w': 32, 'h': 32},
        ],
        'fps': 10,
        'events': [
          {'frame': 1, 'type': 'signal', 'name': 'footstep'},
        ],
      },
    };
    final timelines = clipsTimelinesFromProperties({'rustAnimationClips': clips});
    expect(timelines['run']!.events.isNotEmpty, isTrue);
  });
}
