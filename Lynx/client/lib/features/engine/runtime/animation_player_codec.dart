import '../models/engine_models.dart';

/// Сборка `rustAnimationClips` / `rustAnimStateMachine` (волна 5a → 9a/9b).
class AnimationPlayerPreset {
  final Map<String, dynamic> clips;
  final Map<String, dynamic> stateMachine;
  const AnimationPlayerPreset({required this.clips, required this.stateMachine});
}

/// Событие на кадре клипа (волна 9b).
class AnimKeyEvent {
  final int frame;
  final String type;
  final String? name;
  final String? code;

  const AnimKeyEvent({
    required this.frame,
    required this.type,
    this.name,
    this.code,
  });

  Map<String, dynamic> toJson() => {
        'frame': frame,
        'type': type,
        if (name != null) 'name': name,
        if (code != null) 'code': code,
      };

  static AnimKeyEvent? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final frame = (raw['frame'] as num?)?.toInt();
    final type = raw['type'] as String?;
    if (frame == null || type == null) return null;
    return AnimKeyEvent(
      frame: frame,
      type: type,
      name: raw['name'] as String?,
      code: raw['code'] as String?,
    );
  }
}

/// Дорожка клипа для UI (волна 9a).
class AnimationClipTimeline {
  final String clipId;
  final List<Map<String, dynamic>> frames;
  final double fps;
  final List<AnimKeyEvent> events;

  const AnimationClipTimeline({
    required this.clipId,
    required this.frames,
    required this.fps,
    this.events = const [],
  });

  Map<String, dynamic> toClipJson() => {
        'frames': frames,
        'fps': fps,
        if (events.isNotEmpty) 'events': events.map((e) => e.toJson()).toList(),
      };
}

AnimationPlayerPreset? animationPresetFromSpriteMeta(SpriteAssetMeta? meta) {
  if (meta?.sheetAnimation == null) return null;
  final sheet = meta!.sheetAnimation!;
  final frames = sheet.frames
      .map((f) => {'x': f.x, 'y': f.y, 'w': f.w, 'h': f.h})
      .toList();
  if (frames.isEmpty) return null;

  final fps = sheet.fps;
  final clips = <String, dynamic>{
    'idle': {'frames': [frames.first], 'fps': (fps * 0.5).clamp(1, 120)},
    if (frames.length > 1)
      'run': {'frames': frames, 'fps': fps},
  };

  final stateMachine = <String, dynamic>{
    'enabled': true,
    'fallback_clip': 'idle',
    'rules': [
      if (frames.length > 1)
        {
          'clip_id': 'run',
          'conditions': ['speed_x_above'],
          'speed_threshold': 20,
        },
      {
        'clip_id': 'idle',
        'conditions': ['on_ground'],
        'speed_threshold': 0,
      },
    ],
  };

  return AnimationPlayerPreset(clips: clips, stateMachine: stateMachine);
}

Map<String, AnimationClipTimeline> clipsTimelinesFromProperties(
  Map<String, dynamic> properties,
) {
  final rac = properties['rustAnimationClips'];
  if (rac is! Map) return {};
  final out = <String, AnimationClipTimeline>{};
  for (final entry in rac.entries) {
    final id = entry.key.toString();
    if (entry.value is! Map) continue;
    final m = Map<String, dynamic>.from(entry.value as Map);
    final frames = (m['frames'] as List?)
            ?.map((f) => Map<String, dynamic>.from(f as Map))
            .toList() ??
        [];
    final fps = (m['fps'] as num?)?.toDouble() ?? 8;
    final events = <AnimKeyEvent>[];
    final evRaw = m['events'] as List?;
    if (evRaw != null) {
      for (final e in evRaw) {
        final parsed = AnimKeyEvent.fromJson(e);
        if (parsed != null) events.add(parsed);
      }
    }
    out[id] = AnimationClipTimeline(
      clipId: id,
      frames: frames,
      fps: fps,
      events: events,
    );
  }
  return out;
}

Map<String, dynamic> timelinesToClipsJson(Map<String, AnimationClipTimeline> timelines) {
  return {for (final t in timelines.values) t.clipId: t.toClipJson()};
}

/// Строки превью blend tree (волна 9a).
List<String> blendPreviewLines(Map<String, dynamic>? stateMachine) {
  if (stateMachine == null) return const [];
  if (stateMachine['enabled'] != true) return const ['(выключена)'];
  final fallback = stateMachine['fallback_clip'] as String? ?? 'idle';
  final rules = stateMachine['rules'] as List? ?? [];
  final lines = <String>['fallback → $fallback'];
  for (final r in rules) {
    if (r is! Map) continue;
    final clip = r['clip_id'] as String? ?? '?';
    final conds = (r['conditions'] as List?)?.join(' + ') ?? '';
    final thr = r['speed_threshold'];
    lines.add('$clip ← $conds${thr != null ? ' ($thr)' : ''}');
  }
  return lines;
}

Map<String, dynamic> applyAnimationPlayerToProperties(
  Map<String, dynamic> properties,
  AnimationPlayerPreset preset,
) {
  return {
    ...properties,
    'rustAnimationClips': preset.clips,
    'rustAnimStateMachine': preset.stateMachine,
  };
}

Map<String, dynamic> applyTimelinesToProperties(
  Map<String, dynamic> properties,
  Map<String, AnimationClipTimeline> timelines, {
  Map<String, dynamic>? stateMachine,
}) {
  return {
    ...properties,
    'rustAnimationClips': timelinesToClipsJson(timelines),
    if (stateMachine != null) 'rustAnimStateMachine': stateMachine,
  };
}

bool objectHasAnimationPlayer(SceneObject o) {
  return o.properties['rustAnimationClips'] is Map &&
      o.properties['rustAnimStateMachine'] is Map;
}
