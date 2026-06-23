import 'package:flutter/material.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';

Future<void> showSceneRoomsEditorDialog({
  required BuildContext context,
  required SceneProvider sceneProvider,
  required ProjectManager manager,
}) async {
  final scene = sceneProvider.currentScene;
  if (scene == null) return;
  final designW = manager.projectSettings?.designWidth ?? 1280;
  final designH = manager.projectSettings?.designHeight ?? 720;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _RoomsEditorDialog(
      initialRooms: List<RoomZoneData>.from(scene.rooms),
      designWidth: designW,
      designHeight: designH,
      sceneIds: manager.scenes.map((s) => s.id).toList(),
      sceneNames: {for (final s in manager.scenes) s.id: s.name},
      onApply: (next) {
        sceneProvider.replaceSceneRooms(next);
        manager.scheduleSceneSave();
      },
    ),
  );
}

class _RoomsEditorDialog extends StatefulWidget {
  const _RoomsEditorDialog({
    required this.initialRooms,
    required this.designWidth,
    required this.designHeight,
    required this.sceneIds,
    required this.sceneNames,
    required this.onApply,
  });

  final List<RoomZoneData> initialRooms;
  final double designWidth;
  final double designHeight;
  final List<String> sceneIds;
  final Map<String, String> sceneNames;
  final void Function(List<RoomZoneData> rooms) onApply;

  @override
  State<_RoomsEditorDialog> createState() => _RoomsEditorDialogState();
}

class _RoomsEditorDialogState extends State<_RoomsEditorDialog> {
  late List<RoomZoneData> _rooms;

  @override
  void initState() {
    super.initState();
    _rooms = List<RoomZoneData>.from(widget.initialRooms);
  }

  Future<RoomZoneData?> _promptRoom(RoomZoneData current) async {
    final idC = TextEditingController(text: current.id);
    final xC = TextEditingController(text: _fmt(current.x));
    final yC = TextEditingController(text: _fmt(current.y));
    final wC = TextEditingController(text: _fmt(current.w));
    final hC = TextEditingController(text: _fmt(current.h));
    final cminxC = TextEditingController(text: _fmt(current.cameraMinX));
    final cminyC = TextEditingController(text: _fmt(current.cameraMinY));
    final cmaxxC = TextEditingController(text: _fmt(current.cameraMaxX));
    final cmaxyC = TextEditingController(text: _fmt(current.cameraMaxY));
    var targetScene = current.targetSceneId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Зона комнаты'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idC,
                  decoration: const InputDecoration(labelText: 'id'),
                ),
                if (widget.sceneIds.length > 1) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: targetScene,
                    decoration: const InputDecoration(
                      labelText: 'Сцена-холст',
                      helperText: 'Отдельный JSON в scenes/ для этой комнаты',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— текущая —')),
                      for (final sid in widget.sceneIds)
                        DropdownMenuItem(
                          value: sid,
                          child: Text(widget.sceneNames[sid] ?? sid),
                        ),
                    ],
                    onChanged: (v) => setLocal(() => targetScene = v),
                  ),
                ],
                TextField(
                  controller: xC,
                decoration: const InputDecoration(labelText: 'x (левый край)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: yC,
                decoration: const InputDecoration(labelText: 'y (верхний край)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: wC,
                decoration: const InputDecoration(labelText: 'w'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: hC,
                decoration: const InputDecoration(labelText: 'h'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Text(
                'Кламп камеры (если max > min)',
                style: Theme.of(ctx).textTheme.labelSmall,
              ),
              TextField(
                controller: cminxC,
                decoration: const InputDecoration(labelText: 'camera_min_x'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: cminyC,
                decoration: const InputDecoration(labelText: 'camera_min_y'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: cmaxxC,
                decoration: const InputDecoration(labelText: 'camera_max_x'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              TextField(
                controller: cmaxyC,
                decoration: const InputDecoration(labelText: 'camera_max_y'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    ),
    );

    RoomZoneData? out;
    if (ok == true) {
      out = RoomZoneData(
        id: idC.text.trim().isEmpty ? current.id : idC.text.trim(),
        x: double.tryParse(xC.text.replaceAll(',', '.')) ?? current.x,
        y: double.tryParse(yC.text.replaceAll(',', '.')) ?? current.y,
        w: double.tryParse(wC.text.replaceAll(',', '.')) ?? current.w,
        h: double.tryParse(hC.text.replaceAll(',', '.')) ?? current.h,
        cameraMinX: double.tryParse(cminxC.text.replaceAll(',', '.')) ?? current.cameraMinX,
        cameraMinY: double.tryParse(cminyC.text.replaceAll(',', '.')) ?? current.cameraMinY,
        cameraMaxX: double.tryParse(cmaxxC.text.replaceAll(',', '.')) ?? current.cameraMaxX,
        cameraMaxY: double.tryParse(cmaxyC.text.replaceAll(',', '.')) ?? current.cameraMaxY,
        targetSceneId: targetScene,
      );
    }
    idC.dispose();
    xC.dispose();
    yC.dispose();
    wC.dispose();
    hC.dispose();
    cminxC.dispose();
    cminyC.dispose();
    cmaxxC.dispose();
    cmaxyC.dispose();
    return out;
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Комнаты камеры'),
      content: SizedBox(
        width: 380,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Прямоугольник в мировых координатах: игрок внутри зоны активирует кламп камеры (см. GAME_AUTHOR.md).',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                FilledButton.tonal(
                  onPressed: () async {
                    final next = await _promptRoom(
                      RoomZoneData(
                        id: 'room_${DateTime.now().millisecondsSinceEpoch}',
                        x: 0,
                        y: 0,
                        w: widget.designWidth,
                        h: widget.designHeight,
                      ),
                    );
                    final added = next;
                    if (added != null && mounted) {
                      setState(() => _rooms.add(added));
                    }
                  },
                  child: const Text('Новая зона'),
                ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _rooms.add(
                        RoomZoneData(
                          id: 'main_${DateTime.now().millisecondsSinceEpoch}',
                          x: 0,
                          y: 0,
                          w: widget.designWidth,
                          h: widget.designHeight,
                        ),
                      );
                    });
                  },
                  child: Text('На весь дизайн (${widget.designWidth.toInt()}×${widget.designHeight.toInt()})'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _rooms.isEmpty
                  ? Center(
                      child: Text(
                        'Нет зон — камера не клампится по комнатам.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rooms.length,
                      itemBuilder: (ctx, i) {
                        final r = _rooms[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(r.id, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${_fmt(r.x)}, ${_fmt(r.y)} · ${_fmt(r.w)}×${_fmt(r.h)}'
                              '${r.targetSceneId != null ? ' → ${widget.sceneNames[r.targetSceneId] ?? r.targetSceneId}' : ''}',
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Изменить',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () async {
                                    final next = await _promptRoom(r);
                                    final edited = next;
                                    if (edited != null && mounted) {
                                      setState(() => _rooms[i] = edited);
                                    }
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Удалить',
                                  icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                                  onPressed: () => setState(() => _rooms.removeAt(i)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            widget.onApply(_rooms);
            Navigator.pop(context);
          },
          child: const Text('Сохранить в сцену'),
        ),
      ],
    );
  }
}
