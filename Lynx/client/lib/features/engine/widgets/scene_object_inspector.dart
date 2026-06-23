import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';
import '../providers/scene_provider.dart';
import 'animation_player_panel.dart';
import 'behavior_tree_editor_dialog.dart';
import 'lynx_blueprint_editor_dialog.dart';
import '../runtime/lynx_blueprint_service.dart';
import '../runtime/lynx_graph_compiler.dart';
import '../runtime/lynx_graph_model.dart';
import '../runtime/prefab_baseline_utils.dart';
import '../runtime/scene_hierarchy_utils.dart';
import '../runtime/scene_ui_codec.dart';
import 'ui_layout_preview_panel.dart';
import '../../plugins/lynx_plugin_host.dart';
import '../../plugins/lynx_3d/lynx_3d_object_inspector.dart';

class SceneObjectInspector extends StatefulWidget {
  final SceneObject object;

  const SceneObjectInspector({super.key, required this.object});

  @override
  State<SceneObjectInspector> createState() => _SceneObjectInspectorState();
}

class _SceneObjectInspectorState extends State<SceneObjectInspector> {
  late final TextEditingController _name;
  late final TextEditingController _x;
  late final TextEditingController _y;
  late final TextEditingController _z;
  late final TextEditingController _w;
  late final TextEditingController _h;
  late final TextEditingController _rot;
  late final TextEditingController _sx;
  late final TextEditingController _sy;
  late final TextEditingController _ox;
  late final TextEditingController _oy;
  late final TextEditingController _sortLayerOverride;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _x = TextEditingController();
    _y = TextEditingController();
    _z = TextEditingController();
    _w = TextEditingController();
    _h = TextEditingController();
    _rot = TextEditingController();
    _sx = TextEditingController();
    _sy = TextEditingController();
    _ox = TextEditingController();
    _oy = TextEditingController();
    _sortLayerOverride = TextEditingController();
    _applyObjectToControllers(widget.object);
  }

  @override
  void didUpdateWidget(covariant SceneObjectInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.id != widget.object.id ||
        !identical(oldWidget.object, widget.object)) {
      _applyObjectToControllers(widget.object);
    }
  }

  void _applyObjectToControllers(SceneObject o) {
    _name.text = o.name;
    _x.text = _fmt(o.x);
    _y.text = _fmt(o.y);
    _z.text = _fmt(o.z);
    _w.text = _fmt(o.width);
    _h.text = _fmt(o.height);
    _rot.text = _fmt(o.rotation);
    _sx.text = _fmt(o.scaleX);
    _sy.text = _fmt(o.scaleY);
    _ox.text = _fmt(o.originX);
    _oy.text = _fmt(o.originY);
    final slo = o.properties['sortingLayerOverride'];
    _sortLayerOverride.text =
        slo == null ? '' : (slo is num ? slo.toInt().toString() : slo.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _x.dispose();
    _y.dispose();
    _z.dispose();
    _w.dispose();
    _h.dispose();
    _rot.dispose();
    _sx.dispose();
    _sy.dispose();
    _ox.dispose();
    _oy.dispose();
    _sortLayerOverride.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  double? _parseD(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  void _patchSceneObject(SceneObject next) {
    final scene = context.read<SceneProvider>();
    final mgr = context.read<ProjectManager>();
    scene.maybePushUndoBeforeInspectorEdit(next.id);
    scene.updateObject(next);
    mgr.scheduleSceneSave();
  }

  Widget _prefabSection(
    Scene scene,
    SceneObject o,
    ProjectManager manager,
    ColorScheme cs,
  ) {
    final def = manager.prefabById(o.prefabId);
    if (def == null) {
      return Card(
        margin: EdgeInsets.zero,
        color: cs.errorContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            'prefabId: ${o.prefabId} — префаб не найден в проекте.',
            style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
          ),
        ),
      );
    }
    final baseline = prefabBaselineForInstance(scene, o, def);
    final diffs = baseline == null ? <String>[] : prefabDiffLabels(o, baseline);
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.widgets_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Префаб: ${def.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              baseline == null
                  ? 'Состав поддерева на сцене не совпадает с префабом — сброс к шаблону для этого узла недоступен.'
                  : (diffs.isEmpty
                      ? 'Все поля совпадают с шаблоном префаба.'
                      : 'Отличия от шаблона:'),
              style: TextStyle(fontSize: 11, height: 1.35, color: cs.onSurfaceVariant),
            ),
            if (baseline != null && diffs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in diffs)
                    Chip(
                      label: Text(d, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
            ],
            if (baseline != null && diffs.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: manager.isCloudReadOnly
                    ? null
                    : () {
                        final next = revertInstanceToPrefabTemplate(o, baseline);
                        _patchSceneObject(next);
                      },
                icon: const Icon(Icons.restore_page_outlined, size: 18),
                label: const Text('Сбросить к префабу'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _staticBody(SceneObject o) {
    final p = o.properties['static'];
    return p == true || p == 'true';
  }

  Map<String, dynamic> _withStatic(SceneObject o, bool v) {
    final m = Map<String, dynamic>.from(o.properties);
    m['static'] = v;
    return m;
  }

  Map<String, dynamic> _propsWith(SceneObject o, String key, Object? value) {
    final m = Map<String, dynamic>.from(o.properties);
    if (value == null) {
      m.remove(key);
    } else {
      m[key] = value;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final sceneProvider = context.watch<SceneProvider>();
    final manager = context.watch<ProjectManager>();
    final scene = sceneProvider.currentScene;
    if (scene == null) return const SizedBox.shrink();

    final o = widget.object;
    final cs = Theme.of(context).colorScheme;
    final scripts = manager.assets.where((a) => a.type == 'script').toList();
    final sprites = manager.assets.where((a) => a.type == 'sprite').toList();

    final layerValue = () {
      final id = o.layerId ?? SceneLayer.defaultLayerId;
      if (scene.layers.any((l) => l.id == id)) return id;
      return SceneLayer.defaultLayerId;
    }();

    final assetValue = () {
      if (o.assetId == 'test' || o.assetId.isEmpty) return 'test';
      if (sprites.any((a) => a.id == o.assetId)) return o.assetId;
      return 'test';
    }();

    final scriptIds = <String?>{null, ...scripts.map((a) => a.id)};
    final scriptValue = o.scriptId != null && scriptIds.contains(o.scriptId)
        ? o.scriptId
        : null;

    final validParents = validParentCandidates(scene, o.id);
    final parentFieldValue = () {
      final pid = o.parentId;
      if (pid == null) return null;
      if (validParents.any((x) => x.id == pid)) return pid;
      return null;
    }();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Icon(Icons.tune, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Объект сцены',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Удалить объект',
                icon: Icon(Icons.delete_outline, color: cs.error),
                onPressed: manager.isCloudReadOnly
                    ? null
                    : () {
                        sceneProvider.removeObject(o.id);
                        manager.scheduleSceneSave();
                      },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (o.prefabId != null) ...[
                _prefabSection(scene, o, manager, cs),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  isDense: true,
                ),
                onSubmitted: (_) {
                  final t = _name.text.trim();
                  if (t.isEmpty) return;
                  _patchSceneObject(o.copyWith(name: t));
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('${o.id}_layer_$layerValue'),
                initialValue: layerValue,
                decoration: const InputDecoration(
                  labelText: 'Слой',
                  isDense: true,
                ),
                items: [
                  for (final layer in scene.layers)
                    DropdownMenuItem(value: layer.id, child: Text(layer.name)),
                ],
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) {
                        if (v == null) return;
                        _patchSceneObject(o.copyWith(layerId: v));
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey('${o.id}_parent_$parentFieldValue'),
                initialValue: parentFieldValue,
                decoration: InputDecoration(
                  labelText: 'Родитель (Hierarchy)',
                  isDense: true,
                  helperText: o.parentId != null && parentFieldValue == null
                      ? 'Текущий родитель недопустим (цикл или ссылка); выберите другого или корень'
                      : 'Дочерние двигаются с родителем; циклы parent → child не допускаются',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— нет (корень) —'),
                  ),
                  for (final other in validParents)
                    DropdownMenuItem<String?>(
                      value: other.id,
                      child: Text(other.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) {
                        if (v == o.parentId) return;
                        if (v == null) {
                          _patchSceneObject(o.copyWith(clearParentId: true));
                          return;
                        }
                        if (v == o.id) return;
                        if (wouldCreateParentCycle(scene.objects, o.id, v)) {
                          return;
                        }
                        _patchSceneObject(o.copyWith(parentId: v));
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('${o.id}_asset_$assetValue'),
                initialValue: assetValue,
                decoration: const InputDecoration(
                  labelText: 'Спрайт / ассет',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: 'test', child: Text('test (цветной блок)')),
                  ...sprites.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ),
                ],
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) {
                        if (v == null) return;
                        _patchSceneObject(o.copyWith(assetId: v));
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: ValueKey('${o.id}_script_$scriptValue'),
                initialValue: scriptValue,
                decoration: const InputDecoration(
                  labelText: 'Скрипт (Lua / LynxScript)',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— нет —')),
                  ...scripts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ),
                ],
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) {
                        _patchSceneObject(o.copyWith(scriptId: v));
                      },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: manager.isCloudReadOnly
                    ? null
                    : () async {
                        final prop = o.properties['lynxGraph'];
                        LynxGraphDocument? initial;
                        if (prop is Map) {
                          initial = tryParseLynxGraphJson(Map<String, dynamic>.from(prop));
                        }
                        if (initial == null && o.scriptId != null) {
                          for (final a in manager.assets) {
                            if (a.id == o.scriptId) {
                              initial = await loadGraphSidecar(manager, a);
                              break;
                            }
                          }
                        }
                        if (!context.mounted) return;
                        final result = await showLynxBlueprintEditor(
                          context,
                          initial: initial ?? LynxGraphDocument.defaultPlayerController(),
                        );
                        if (result == null || !context.mounted) return;
                        try {
                          final scriptText = compileLynxGraphToScript(result);
                          final asset = await manager.createLynxScriptAsset(
                            '${o.name}_blueprint',
                            scriptText,
                            graphJson: result.toJson(),
                          );
                          if (asset != null) {
                            _patchSceneObject(
                              o.copyWith(
                                scriptId: asset.id,
                                properties: {...o.properties, 'lynxGraph': result.toJson()},
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Blueprint: $e')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.hub_outlined, size: 18),
                label: const Text('Blueprint (LynxGraph)'),
              ),
              const SizedBox(height: 12),
              Text('Transform', style: TextStyle(color: cs.primary, fontSize: 12)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _x,
                      decoration: const InputDecoration(labelText: 'X', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_x.text);
                        if (v != null) _patchSceneObject(o.copyWith(x: v));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _y,
                      decoration: const InputDecoration(labelText: 'Y', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_y.text);
                        if (v != null) _patchSceneObject(o.copyWith(y: v));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _z,
                decoration: const InputDecoration(
                  labelText: 'Z (order in layer)',
                  helperText: 'Влияет на порядок отрисовки внутри слоя при экспорте в движок',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onSubmitted: (_) {
                  final v = _parseD(_z.text);
                  if (v != null) _patchSceneObject(o.copyWith(z: v));
                },
              ),
              const SizedBox(height: 12),
              Text('2D / рендер', style: TextStyle(color: cs.primary, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: _sortLayerOverride,
                decoration: const InputDecoration(
                  labelText: 'Sorting layer (override)',
                  helperText: 'Пусто = брать порядок из выбранного слоя сцены. Число = как Unity sorting layer.',
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                onSubmitted: (_) {
                  final t = _sortLayerOverride.text.trim();
                  if (t.isEmpty) {
                    _patchSceneObject(o.copyWith(properties: _propsWith(o, 'sortingLayerOverride', null)));
                    return;
                  }
                  final v = int.tryParse(t.replaceAll(',', ''));
                  if (v != null) {
                    _patchSceneObject(o.copyWith(properties: _propsWith(o, 'sortingLayerOverride', v)));
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Триггер коллайдера'),
                subtitle: const Text(
                  'Без отталкивания. В Lua: on_trigger_enter() / on_trigger_exit() — глобал other_id',
                ),
                value: o.properties['isTrigger'] == true,
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) => _patchSceneObject(o.copyWith(properties: _propsWith(o, 'isTrigger', v))),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _w,
                      decoration: const InputDecoration(labelText: 'Ширина', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_w.text);
                        if (v != null) _patchSceneObject(o.copyWith(width: v));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _h,
                      decoration: const InputDecoration(labelText: 'Высота', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_h.text);
                        if (v != null) _patchSceneObject(o.copyWith(height: v));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rot,
                decoration: const InputDecoration(labelText: 'Поворот (град.)', isDense: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSubmitted: (_) {
                  final v = _parseD(_rot.text);
                  if (v != null) _patchSceneObject(o.copyWith(rotation: v));
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sx,
                      decoration: const InputDecoration(labelText: 'Scale X', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_sx.text);
                        if (v != null) _patchSceneObject(o.copyWith(scaleX: v));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sy,
                      decoration: const InputDecoration(labelText: 'Scale Y', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_sy.text);
                        if (v != null) _patchSceneObject(o.copyWith(scaleY: v));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ox,
                      decoration: const InputDecoration(labelText: 'Origin X 0–1', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_ox.text);
                        if (v != null) _patchSceneObject(o.copyWith(originX: v));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _oy,
                      decoration: const InputDecoration(labelText: 'Origin Y 0–1', isDense: true),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onSubmitted: (_) {
                        final v = _parseD(_oy.text);
                        if (v != null) _patchSceneObject(o.copyWith(originY: v));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Видимость', style: TextStyle(color: cs.primary, fontSize: 12)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Активен'),
                value: o.active,
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) => _patchSceneObject(o.copyWith(active: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Видимый'),
                value: o.visible,
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) => _patchSceneObject(o.copyWith(visible: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Заблокирован (нельзя двигать)'),
                value: o.locked,
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) => _patchSceneObject(o.copyWith(locked: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Статичное тело (коллизия, без Lua)'),
                subtitle: const Text('Свойство static — пол/платформа'),
                value: _staticBody(o),
                onChanged: manager.isCloudReadOnly
                    ? null
                    : (v) => _patchSceneObject(o.copyWith(properties: _withStatic(o, v))),
              ),
              const SizedBox(height: 12),
              Text('Редактор Pro', style: TextStyle(color: cs.primary, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    onPressed: manager.isCloudReadOnly
                        ? null
                        : () => showAnimationPlayerPanel(
                              context,
                              object: o,
                              onApply: _patchSceneObject,
                            ),
                    icon: const Icon(Icons.animation_outlined, size: 18),
                    label: const Text('AnimationPlayer'),
                  ),
                  OutlinedButton.icon(
                    onPressed: manager.isCloudReadOnly
                        ? null
                        : () async {
                            final bt = o.properties['rustBehaviorTree'];
                            final result = await showBehaviorTreeEditor(
                              context,
                              initial: bt is Map ? Map<String, dynamic>.from(bt) : null,
                            );
                            if (result != null) {
                              _patchSceneObject(
                                o.copyWith(
                                  properties: {...o.properties, 'rustBehaviorTree': result},
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.account_tree_outlined, size: 18),
                    label: const Text('Behavior Tree'),
                  ),
                  OutlinedButton.icon(
                    onPressed: manager.isCloudReadOnly
                        ? null
                        : () {
                            _patchSceneObject(
                              o.copyWith(
                                layerId: SceneLayer.uiLayerId,
                                properties: defaultUiButtonAnchoredProperties(
                                  'Play',
                                  'load_scene:main',
                                ),
                                width: o.width <= 0 ? 180 : o.width,
                                height: o.height <= 0 ? 44 : o.height,
                              ),
                            );
                          },
                    icon: const Icon(Icons.widgets_outlined, size: 18),
                    label: const Text('UI кнопка (anchor)'),
                  ),
                  if (o.layerId == SceneLayer.uiLayerId ||
                      o.properties['lynxUi'] is Map) ...[
                    const SizedBox(height: 8),
                    UiLayoutPreviewPanel(
                      object: o,
                      baseDesignW: (manager.projectSettings?.designWidth ?? 1280).toDouble(),
                      baseDesignH: (manager.projectSettings?.designHeight ?? 720).toDouble(),
                    ),
                  ],
                ],
              ),
              if (LynxPluginHost.instance.is3dActive) ...[
                const SizedBox(height: 12),
                Lynx3dObjectInspectorSection(object: o),
              ],
              const SizedBox(height: 8),
              Text(
                'id: ${o.id}',
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
