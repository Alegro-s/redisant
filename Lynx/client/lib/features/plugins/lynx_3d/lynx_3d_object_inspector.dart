import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../engine/models/engine_models.dart';
import '../../engine/providers/scene_provider.dart';
import '../lynx_plugin_host.dart';
import '../lynx_plugin_manifest.dart';
import 'gltf_import_io.dart';
import 'lynx_3d_codec.dart';

/// Блок инспектора для `properties.lynx.3d`.
class Lynx3dObjectInspectorSection extends StatefulWidget {
  const Lynx3dObjectInspectorSection({
    super.key,
    required this.object,
  });

  final SceneObject object;

  @override
  State<Lynx3dObjectInspectorSection> createState() =>
      _Lynx3dObjectInspectorSectionState();
}

class _Lynx3dObjectInspectorSectionState extends State<Lynx3dObjectInspectorSection> {
  late bool _enabled;
  late TextEditingController _meshCtrl;
  late double _px;
  late double _py;
  late double _pz;
  late double _hx;
  late double _hy;
  late double _hz;
  late double _metallic;
  late double _roughness;
  late TextEditingController _albedoCtrl;
  late TextEditingController _normalCtrl;
  late TextEditingController _animClipCtrl;

  @override
  void initState() {
    super.initState();
    _meshCtrl = TextEditingController();
    _albedoCtrl = TextEditingController();
    _normalCtrl = TextEditingController();
    _animClipCtrl = TextEditingController();
    _load();
  }

  void _load() {
    final block = widget.object.properties[Lynx3dPluginIds.objectPropertyKey];
    _enabled = block is Map;
    if (block is Map) {
      final spec = Lynx3dObjectSpec.fromMap(
        Map<String, dynamic>.from(block)..['id'] = widget.object.id,
      );
      _meshCtrl.text = spec.mesh ?? '';
      _albedoCtrl.text = spec.material.albedoTexture ?? '';
      _normalCtrl.text = spec.material.normalTexture ?? '';
      _animClipCtrl.text = spec.animationClip ?? '';
      _px = spec.position[0];
      _py = spec.position[1];
      _pz = spec.position[2];
      _hx = spec.halfExtents[0];
      _hy = spec.halfExtents[1];
      _hz = spec.halfExtents[2];
      _metallic = spec.material.metallic ?? 0.1;
      _roughness = spec.material.roughness ?? 0.65;
    } else {
      _meshCtrl.text = '';
      _albedoCtrl.text = '';
      _normalCtrl.text = '';
      _animClipCtrl.text = '';
      _px = 0;
      _py = 1;
      _pz = 0;
      _hx = _hy = _hz = 0.5;
      _metallic = 0.1;
      _roughness = 0.65;
    }
  }

  @override
  void didUpdateWidget(covariant Lynx3dObjectInspectorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.id != widget.object.id) _load();
  }

  @override
  void dispose() {
    _meshCtrl.dispose();
    _albedoCtrl.dispose();
    _normalCtrl.dispose();
    _animClipCtrl.dispose();
    super.dispose();
  }

  void _commit() {
    final sp = context.read<SceneProvider>();
    sp.pushUndoSnapshot();
    if (!_enabled) {
      final props = Map<String, dynamic>.from(widget.object.properties);
      props.remove(Lynx3dPluginIds.objectPropertyKey);
      sp.updateObject(widget.object.copyWith(properties: props));
      return;
    }
    final albedo = _albedoCtrl.text.trim();
    final normal = _normalCtrl.text.trim();
    final clip = _animClipCtrl.text.trim();
    final props = Map<String, dynamic>.from(widget.object.properties);
    props[Lynx3dPluginIds.objectPropertyKey] = {
      'mesh': _meshCtrl.text.trim().isEmpty ? null : _meshCtrl.text.trim(),
      'transform': {
        'position': [_px, _py, _pz],
        'rotationEuler': [0, 0, 0],
        'scale': [1, 1, 1],
      },
      'halfExtents': [_hx, _hy, _hz],
      'color': '#8D6E63',
      'material': {
        'metallic': _metallic,
        'roughness': _roughness,
        if (albedo.isNotEmpty) 'albedoTexture': albedo,
        if (normal.isNotEmpty) 'normalTexture': normal,
      },
      if (clip.isNotEmpty) 'animationClip': clip,
    };
    sp.updateObject(widget.object.copyWith(properties: props));
    setState(() {});
  }

  Future<void> _importGlb() async {
    final root = LynxPluginHost.instance.context?.projectRoot;
    if (root == null) return;
    final rel = await LynxGltfImport.pickAndImportGlb(root);
    if (rel == null || !mounted) return;
    setState(() => _meshCtrl.text = rel);
    _enabled = true;
    _commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортирован: $rel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lynx 3D объект'),
          subtitle: const Text('properties.lynx.3d'),
          value: _enabled,
          onChanged: (v) {
            setState(() => _enabled = v);
            _commit();
          },
        ),
        if (_enabled) ...[
          TextField(
            decoration: const InputDecoration(
              labelText: 'Mesh (glb/gltf путь)',
              isDense: true,
            ),
            controller: _meshCtrl,
            onSubmitted: (_) => _commit(),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _importGlb,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Импорт GLB/GLTF…'),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Albedo texture',
              isDense: true,
            ),
            controller: _albedoCtrl,
            onSubmitted: (_) => _commit(),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Normal map',
              isDense: true,
            ),
            controller: _normalCtrl,
            onSubmitted: (_) => _commit(),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Animation clip',
              isDense: true,
            ),
            controller: _animClipCtrl,
            onSubmitted: (_) => _commit(),
          ),
          _slider('Metallic', _metallic, 0, 1, (v) => _metallic = v),
          _slider('Roughness', _roughness, 0, 1, (v) => _roughness = v),
          _slider('X', _px, -8, 8, (v) => _px = v),
          _slider('Y', _py, 0, 8, (v) => _py = v),
          _slider('Z', _pz, -8, 8, (v) => _pz = v),
          const Text('Half extents (AABB)', style: TextStyle(fontSize: 12)),
          _slider('HX', _hx, 0.1, 2, (v) => _hx = v),
          _slider('HY', _hy, 0.1, 2, (v) => _hy = v),
          _slider('HZ', _hz, 0.1, 2, (v) => _hz = v),
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
