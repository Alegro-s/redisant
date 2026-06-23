import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';
import '../runtime/animation_player_codec.dart';

/// AnimationPlayer v2: дорожки, key events, blend preview (волна 9).
Future<void> showAnimationPlayerPanel(
  BuildContext context, {
  required SceneObject object,
  required void Function(SceneObject next) onApply,
}) async {
  final manager = context.read<ProjectManager>();
  final hasAnim = objectHasAnimationPlayer(object);
  SpriteAssetMeta? meta;
  if (object.assetId != null && manager.rootPath != null) {
    meta = await manager.readSpriteMetaForAssetId(object.assetId!);
  }
  final preset = animationPresetFromSpriteMeta(meta);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return _AnimationPlayerSheet(
        object: object,
        hasAnim: hasAnim,
        preset: preset,
        onApply: onApply,
      );
    },
  );
}

class _AnimationPlayerSheet extends StatefulWidget {
  final SceneObject object;
  final bool hasAnim;
  final AnimationPlayerPreset? preset;
  final void Function(SceneObject next) onApply;

  const _AnimationPlayerSheet({
    required this.object,
    required this.hasAnim,
    required this.preset,
    required this.onApply,
  });

  @override
  State<_AnimationPlayerSheet> createState() => _AnimationPlayerSheetState();
}

class _AnimationPlayerSheetState extends State<_AnimationPlayerSheet> {
  late Map<String, AnimationClipTimeline> _timelines;
  Map<String, dynamic>? _stateMachine;
  String? _selectedClipId;
  int _previewFrame = 0;

  @override
  void initState() {
    super.initState();
    _timelines = clipsTimelinesFromProperties(widget.object.properties);
    final sm = widget.object.properties['rustAnimStateMachine'];
    _stateMachine = sm is Map ? Map<String, dynamic>.from(sm) : null;
    _selectedClipId = _timelines.keys.isNotEmpty ? _timelines.keys.first : null;
  }

  void _applyToObject() {
    widget.onApply(
      widget.object.copyWith(
        properties: applyTimelinesToProperties(
          widget.object.properties,
          _timelines,
          stateMachine: _stateMachine,
        ),
      ),
    );
    Navigator.pop(context);
  }

  void _addSignalEvent(String clipId, int frame) {
    final t = _timelines[clipId];
    if (t == null) return;
    final events = List<AnimKeyEvent>.from(t.events)
      ..add(AnimKeyEvent(frame: frame, type: 'signal', name: 'footstep'));
    setState(() {
      _timelines[clipId] = AnimationClipTimeline(
        clipId: clipId,
        frames: t.frames,
        fps: t.fps,
        events: events,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blendLines = blendPreviewLines(_stateMachine);
    final clip = _selectedClipId != null ? _timelines[_selectedClipId] : null;
    final frameCount = clip?.frames.length ?? 0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListView(
              controller: scrollController,
              children: [
                Text('AnimationPlayer v2', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  widget.hasAnim
                      ? 'Дорожки клипов, события на кадрах, превью blend tree.'
                      : widget.preset == null
                          ? 'Нет sheetAnimation в .meta.json.'
                          : 'Применить клипы из meta спрайта.',
                  style: theme.textTheme.bodySmall,
                ),
                if (blendLines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Blend tree', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: blendLines
                            .map((l) => Text(l, style: theme.textTheme.bodySmall))
                            .toList(),
                      ),
                    ),
                  ),
                ],
                if (_timelines.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Дорожки', style: theme.textTheme.titleSmall),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final id in _timelines.keys)
                        ChoiceChip(
                          label: Text(id),
                          selected: _selectedClipId == id,
                          onSelected: (_) => setState(() {
                            _selectedClipId = id;
                            _previewFrame = 0;
                          }),
                        ),
                    ],
                  ),
                  if (clip != null && frameCount > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Кадры: ${clip.fps.toStringAsFixed(0)} fps · события: ${clip.events.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                    SizedBox(
                      height: 56,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: frameCount,
                        itemBuilder: (_, i) {
                          final hasEv = clip.events.any((e) => e.frame == i);
                          final selected = _previewFrame == i;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setState(() => _previewFrame = i),
                              onLongPress: () => _addSignalEvent(clip.clipId, i),
                              child: Container(
                                width: 44,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor,
                                    width: selected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  color: hasEv
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('$i', style: theme.textTheme.labelSmall),
                                    if (hasEv)
                                      Icon(
                                        Icons.bolt,
                                        size: 14,
                                        color: theme.colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Text(
                      'Тап — кадр · долгий тап — добавить signal footstep',
                      style: theme.textTheme.labelSmall,
                    ),
                    if (clip.events.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...clip.events.map(
                        (e) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('f${e.frame} ${e.type} ${e.name ?? e.code ?? ''}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                final ev = List<AnimKeyEvent>.from(clip.events)
                                  ..remove(e);
                                _timelines[clip.clipId] = AnimationClipTimeline(
                                  clipId: clip.clipId,
                                  frames: clip.frames,
                                  fps: clip.fps,
                                  events: ev,
                                );
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
                const SizedBox(height: 16),
                if (widget.preset != null && _timelines.isEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      final p = widget.preset!;
                      setState(() {
                        _timelines = clipsTimelinesFromProperties(
                          applyAnimationPlayerToProperties({}, p),
                        );
                        _stateMachine = Map<String, dynamic>.from(p.stateMachine);
                        _selectedClipId =
                            _timelines.keys.isEmpty ? null : _timelines.keys.first;
                      });
                    },
                    icon: const Icon(Icons.animation_outlined),
                    label: const Text('Применить из meta'),
                  ),
                if (_timelines.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _applyToObject,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(widget.hasAnim ? 'Сохранить в объект' : 'Применить AnimationPlayer'),
                  ),
                if (widget.hasAnim)
                  TextButton.icon(
                    onPressed: () {
                      final p = Map<String, dynamic>.from(widget.object.properties);
                      p.remove('rustAnimationClips');
                      p.remove('rustAnimStateMachine');
                      widget.onApply(widget.object.copyWith(properties: p));
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Удалить AnimationPlayer'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
