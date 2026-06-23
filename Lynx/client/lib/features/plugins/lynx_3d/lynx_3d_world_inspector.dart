import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/providers/scene_provider.dart';
import '../lynx_plugin_manifest.dart';
import 'lynx_3d_codec.dart';

/// Level 2: world render / terrain / lighting в `extensions.lynx.3d`.
class Lynx3dWorldInspectorPanel extends StatefulWidget {
  const Lynx3dWorldInspectorPanel({super.key});

  @override
  State<Lynx3dWorldInspectorPanel> createState() =>
      _Lynx3dWorldInspectorPanelState();
}

class _Lynx3dWorldInspectorPanelState extends State<Lynx3dWorldInspectorPanel> {
  late Lynx3dRenderSpec _render;
  Lynx3dTerrainSpec? _terrain;
  bool _terrainEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final sp = context.read<SceneProvider>();
    final scene = sp.currentScene;
    final raw = scene?.extensions[Lynx3dPluginIds.sceneExtensionKey] as Map?;
    final ext = Lynx3dSceneExtension.fromMap(
      raw != null ? Map<String, dynamic>.from(raw) : null,
    );
    _render = ext?.render ?? const Lynx3dRenderSpec();
    _terrain = ext?.terrain;
    _terrainEnabled = _terrain != null;
  }

  void _commit() {
    final sp = context.read<SceneProvider>();
    final scene = sp.currentScene;
    if (scene == null) return;
    sp.pushUndoSnapshot();
    final raw = Map<String, dynamic>.from(
      scene.extensions[Lynx3dPluginIds.sceneExtensionKey] as Map? ?? {},
    );
    final world = Map<String, dynamic>.from(raw['world'] as Map? ?? {});
    world['render'] = _render.toMap();
    raw['world'] = world;
    if (_terrainEnabled && _terrain != null) {
      raw['terrain'] = _terrain!.toMap();
    } else {
      raw.remove('terrain');
    }
    sp.setSceneExtension(Lynx3dPluginIds.sceneExtensionKey, raw);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Lynx 3D World (Level 2)'),
      subtitle: const Text('IBL, post, terrain clipmap'),
      children: [
        SwitchListTile(
          title: const Text('Post FX'),
          value: _render.postEnabled,
          onChanged: (v) => setState(() {
            _render = Lynx3dRenderSpec(
              iblStrength: _render.iblStrength,
              postEnabled: v,
              exposure: _render.exposure,
              bloom: _render.bloom,
            );
            _commit();
          }),
        ),
        _slider('IBL', _render.iblStrength, 0, 1, (v) {
          _render = Lynx3dRenderSpec(
            iblStrength: v,
            postEnabled: _render.postEnabled,
            exposure: _render.exposure,
            bloom: _render.bloom,
          );
        }),
        _slider('Exposure', _render.exposure, 0.5, 2.5, (v) {
          _render = Lynx3dRenderSpec(
            iblStrength: _render.iblStrength,
            postEnabled: _render.postEnabled,
            exposure: v,
            bloom: _render.bloom,
          );
        }),
        _slider('Bloom', _render.bloom, 0, 0.5, (v) {
          _render = Lynx3dRenderSpec(
            iblStrength: _render.iblStrength,
            postEnabled: _render.postEnabled,
            exposure: _render.exposure,
            bloom: v,
          );
        }),
        const Divider(),
        SwitchListTile(
          title: const Text('Terrain heightmap'),
          value: _terrainEnabled,
          onChanged: (v) => setState(() {
            _terrainEnabled = v;
            _terrain ??= const Lynx3dTerrainSpec(
              heightmap: 'assets/terrain/hm.png',
              size: [12, 1.5, 12],
              center: [0, 0.5, 0],
              clipmapLevels: 2,
            );
            _commit();
          }),
        ),
        if (_terrainEnabled && _terrain != null) ...[
          TextField(
            decoration: const InputDecoration(
              labelText: 'Heightmap PNG',
              isDense: true,
            ),
            controller: TextEditingController(text: _terrain!.heightmap),
            onSubmitted: (v) {
              _terrain = Lynx3dTerrainSpec(
                heightmap: v.trim(),
                size: _terrain!.size,
                center: _terrain!.center,
                segments: _terrain!.segments,
                maxLod: _terrain!.maxLod,
                lodSplitDistance: _terrain!.lodSplitDistance,
                clipmapLevels: _terrain!.clipmapLevels,
                material: _terrain!.material,
              );
              _commit();
            },
          ),
          _slider('Clipmap levels', _terrain!.clipmapLevels.toDouble(), 1, 4, (v) {
            _terrain = Lynx3dTerrainSpec(
              heightmap: _terrain!.heightmap,
              size: _terrain!.size,
              center: _terrain!.center,
              segments: _terrain!.segments,
              maxLod: _terrain!.maxLod,
              lodSplitDistance: _terrain!.lodSplitDistance,
              clipmapLevels: v.round().clamp(1, 4),
              material: _terrain!.material,
            );
          }),
        ],
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) set,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => setState(() => set(v)),
          onChangeEnd: (_) => _commit(),
        ),
      ],
    );
  }
}
