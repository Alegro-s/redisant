import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../plugins/lynx_plugin_host.dart';
import '../../plugins/lynx_plugin_manifest.dart';
import '../../plugins/lynx_3d/lynx_3d_world_inspector.dart';
import '../providers/scene_provider.dart';

/// Редактирование `scene.extensions` для активных плагинов (волна 1).
class LynxScenePluginsPanel extends StatefulWidget {
  const LynxScenePluginsPanel({super.key});

  @override
  State<LynxScenePluginsPanel> createState() => _LynxScenePluginsPanelState();
}

class _LynxScenePluginsPanelState extends State<LynxScenePluginsPanel> {
  bool _active3d = true;
  String _cameraType = 'perspective';
  double _fovY = 60;
  late final TextEditingController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _ambientCtrl = TextEditingController();
    _loadFromScene();
  }

  @override
  void dispose() {
    _ambientCtrl.dispose();
    super.dispose();
  }

  void _loadFromScene() {
    final scene = context.read<SceneProvider>().currentScene;
    if (scene == null) return;
    final block = scene.extensions[Lynx3dPluginIds.sceneExtensionKey];
    if (block is! Map) return;
    final m = Map<String, dynamic>.from(block);
    _active3d = m['active'] as bool? ?? true;
    final cam = m['camera'] as Map?;
    if (cam != null) {
      _cameraType = cam['type'] as String? ?? 'perspective';
      _fovY = (cam['fovY'] as num?)?.toDouble() ?? 60;
    }
    final world = m['world'] as Map?;
    if (world != null) {
      _ambientCtrl.text = world['ambientColor'] as String? ?? '#404050';
    }
  }

  void _commit() {
    final sp = context.read<SceneProvider>();
    final scene = sp.currentScene;
    if (scene == null) return;
    sp.pushUndoSnapshot();
    final ext = Map<String, dynamic>.from(scene.extensions);
    ext[Lynx3dPluginIds.sceneExtensionKey] = {
      'active': _active3d,
      'world': {
        'ambientColor': _ambientCtrl.text.trim().isEmpty
            ? '#404050'
            : _ambientCtrl.text.trim(),
        'gravity': [0, -9.81, 0],
      },
      'camera': {
        'type': _cameraType,
        'fovY': _fovY,
        'near': 0.1,
        'far': 500,
      },
    };
    scene.extensions = ext;
    scene.bumpRevision();
    sp.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    if (!LynxPluginHost.instance.is3dActive) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Нет активных плагинов сцены.'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          'Плагины сцены',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Lynx 3D активен'),
          subtitle: const Text('extensions.lynx.3d'),
          value: _active3d,
          onChanged: (v) {
            setState(() => _active3d = v);
            _commit();
          },
        ),
        DropdownButtonFormField<String>(
          value: _cameraType,
          decoration: const InputDecoration(labelText: 'Тип камеры', isDense: true),
          items: const [
            DropdownMenuItem(value: 'perspective', child: Text('Perspective')),
            DropdownMenuItem(value: 'orthographic', child: Text('Orthographic')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _cameraType = v);
            _commit();
          },
        ),
        const SizedBox(height: 8),
        Text('FOV Y: ${_fovY.round()}°'),
        Slider(
          value: _fovY,
          min: 30,
          max: 110,
          divisions: 16,
          label: _fovY.round().toString(),
          onChanged: (v) => setState(() => _fovY = v),
          onChangeEnd: (_) => _commit(),
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Ambient (#RRGGBB)',
            isDense: true,
          ),
          controller: _ambientCtrl,
          onSubmitted: (_) => _commit(),
        ),
        const SizedBox(height: 12),
        ...LynxPluginHost.instance.buildEditorPanels(context),
        const Divider(),
        const Lynx3dWorldInspectorPanel(),
        const Divider(),
        const Text(
          'Объекты 3D: инспектор объекта (lynx.3d, импорт GLB). '
          'Viewport orbit — вкладка «3D» в центре.',
          style: TextStyle(fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}
