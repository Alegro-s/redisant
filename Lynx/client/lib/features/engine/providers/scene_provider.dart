import 'dart:convert';

import 'package:flutter/material.dart';

import '../../plugins/lynx_plugin_host.dart';
import '../models/engine_models.dart';
import '../runtime/tilemap_grid.dart';

class SceneProvider extends ChangeNotifier {
  Scene? _currentScene;
  String? _selectedObjectId;
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  String? _undoThrottleObjectId;
  DateTime _undoThrottleAt = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? lastEditorPointerLocal;

  double objectSnapStep = 1.0;

  bool tileEditMode = false;
  int tileLayerIndex = 0;
  int tileBrushCollision = TileCollision.solid;
  int tileManualTileId = 1;

  int tileEditorRevision = 0;

  bool showRoomZones = false;

  bool showSceneGrid = true;

  /// Волна 9c: оверлей collision на тайлмапе в редакторе.
  bool showTileCollisionPreview = true;

  void _bumpTileEditorRevision() {
    tileEditorRevision++;
  }

  Scene? get currentScene => _currentScene;

  String? get selectedObjectId => _selectedObjectId;

  SceneObject? get selectedObject {
    final scene = _currentScene;
    final id = _selectedObjectId;
    if (scene == null || id == null) return null;
    for (final o in scene.objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  void setCurrentScene(Scene scene) {
    LynxPluginHost.instance.applySceneExtensions(scene);
    _currentScene = scene;
    _selectedObjectId = null;
    lastEditorPointerLocal = null;
    tileLayerIndex = 0;
    _undoStack.clear();
    _redoStack.clear();
    _undoThrottleObjectId = null;
    if (scene.tilemaps.isEmpty) {
      tileEditMode = false;
    } else {
      tileLayerIndex = tileLayerIndex.clamp(0, scene.tilemaps.length - 1);
    }
    notifyListeners();
  }

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  void setSceneExtension(String pluginId, Map<String, dynamic> block) {
    if (_currentScene == null) return;
    pushUndoSnapshot();
    final ext = Map<String, dynamic>.from(_currentScene!.extensions);
    ext[pluginId] = block;
    _currentScene!.extensions = ext;
    _currentScene!.bumpRevision();
    notifyListeners();
  }

  void pushUndoSnapshot() {
    if (_currentScene == null) return;
    _undoStack.add(jsonEncode(_currentScene!.toJson()));
    if (_undoStack.length > 64) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void maybePushUndoBeforeInspectorEdit(String objectId) {
    final now = DateTime.now();
    if (_undoThrottleObjectId == objectId &&
        now.difference(_undoThrottleAt).inMilliseconds < 350) {
      return;
    }
    _undoThrottleObjectId = objectId;
    _undoThrottleAt = now;
    pushUndoSnapshot();
  }

  bool undo(void Function(Scene replacement) replaceSceneInProject) {
    if (_undoStack.isEmpty || _currentScene == null) return false;
    _redoStack.add(jsonEncode(_currentScene!.toJson()));
    final prev =
        Scene.fromJson(jsonDecode(_undoStack.removeLast()) as Map<String, dynamic>);
    replaceSceneInProject(prev);
    _currentScene = prev;
    if (_selectedObjectId != null &&
        !_currentScene!.objects.any((o) => o.id == _selectedObjectId)) {
      _selectedObjectId = null;
    }
    notifyListeners();
    return true;
  }

  bool redo(void Function(Scene replacement) replaceSceneInProject) {
    if (_redoStack.isEmpty || _currentScene == null) return false;
    _undoStack.add(jsonEncode(_currentScene!.toJson()));
    final next =
        Scene.fromJson(jsonDecode(_redoStack.removeLast()) as Map<String, dynamic>);
    replaceSceneInProject(next);
    _currentScene = next;
    if (_selectedObjectId != null &&
        !_currentScene!.objects.any((o) => o.id == _selectedObjectId)) {
      _selectedObjectId = null;
    }
    notifyListeners();
    return true;
  }

  void setObjectSnapStep(double step) {
    final s = step.clamp(1.0, 128.0);
    if (objectSnapStep == s) return;
    objectSnapStep = s;
    notifyListeners();
  }

  void setTileEditMode(bool v) {
    if (tileEditMode == v) return;
    tileEditMode = v;
    if (v) {
      _selectedObjectId = null;
    }
    notifyListeners();
  }

  void setTileLayerIndex(int i) {
    final scene = _currentScene;
    if (scene == null || scene.tilemaps.isEmpty) return;
    final c = i.clamp(0, scene.tilemaps.length - 1);
    if (tileLayerIndex == c) return;
    tileLayerIndex = c;
    notifyListeners();
  }

  void setCurrentLayerAutotile(bool v) {
    final scene = _currentScene;
    if (scene == null || scene.tilemaps.isEmpty) return;
    final layers = List<TilemapLayerData>.from(scene.tilemaps);
    final li = tileLayerIndex.clamp(0, layers.length - 1);
    layers[li] = layers[li].copyWith(autotile: v);
    scene.tilemaps = layers;
    scene.modifiedAt = DateTime.now();
    _bumpTileEditorRevision();
    notifyListeners();
  }

  void setTileBrushCollision(int c) {
    if (tileBrushCollision == c) return;
    tileBrushCollision = c;
    notifyListeners();
  }

  void setTileManualTileId(int id) {
    final v = id.clamp(0, 0x7fffffff);
    if (tileManualTileId == v) return;
    tileManualTileId = v;
    notifyListeners();
  }

  void setCurrentLayerTilesetId(String? id) {
    final scene = _currentScene;
    if (scene == null || scene.tilemaps.isEmpty) return;
    final layers = List<TilemapLayerData>.from(scene.tilemaps);
    final li = tileLayerIndex.clamp(0, layers.length - 1);
    layers[li] = layers[li].copyWith(
      tilesetId: id,
      clearTilesetId: id == null || id.isEmpty,
    );
    scene.tilemaps = layers;
    scene.modifiedAt = DateTime.now();
    _bumpTileEditorRevision();
    notifyListeners();
  }

  void paintTileAtEditor(double worldX, double worldY) {
    final scene = _currentScene;
    if (scene == null || !tileEditMode || scene.tilemaps.isEmpty) return;
    final li = tileLayerIndex.clamp(0, scene.tilemaps.length - 1);
    final layer = scene.tilemaps[li];
    final useAutotile = layer.autotile;
    final coll = tileBrushCollision;
    final updated = paintWorldCell(
      layer: layer,
      worldX: worldX,
      worldY: worldY,
      collisionValue: coll,
      manualTileId: tileManualTileId,
      autotile: useAutotile,
    );
    final layers = List<TilemapLayerData>.from(scene.tilemaps);
    layers[li] = updated;
    scene.tilemaps = layers;
    scene.modifiedAt = DateTime.now();
    _bumpTileEditorRevision();
    notifyListeners();
  }

  void selectObject(String? objectId) {
    if (_selectedObjectId == objectId) return;
    _selectedObjectId = objectId;
    notifyListeners();
  }

  void setLastEditorPointerLocal(Offset? o) {
    lastEditorPointerLocal = o;
  }

  void updateObject(SceneObject updated) {
    if (_currentScene == null) return;
    final list = List<SceneObject>.from(_currentScene!.objects);
    final i = list.indexWhere((o) => o.id == updated.id);
    if (i < 0) return;
    list[i] = updated;
    _currentScene!.objects = list;
    _currentScene!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  void updateObjectPosition(String objectId, double x, double y) {
    if (_currentScene == null) return;
    final List<SceneObject> updatedObjects =
        List.from(_currentScene!.objects);
    final index = updatedObjects.indexWhere((o) => o.id == objectId);
    if (index != -1) {
      updatedObjects[index] = updatedObjects[index].copyWith(x: x, y: y);
    }
    _currentScene!.objects = updatedObjects;
    _currentScene!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  void addObject(SceneObject object, {bool skipUndo = false}) {
    if (_currentScene == null) return;
    if (!skipUndo) {
      pushUndoSnapshot();
    }
    final List<SceneObject> updatedObjects =
        List.from(_currentScene!.objects)..add(object);
    _currentScene!.objects = updatedObjects;
    _currentScene!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  void addDefaultTilemapLayer() {
    final scene = _currentScene;
    if (scene == null) return;
    pushUndoSnapshot();
    final n = 32 * 32;
    final chunk = TileChunkData(
      cx: 0,
      cy: 0,
      tw: 32,
      th: 32,
      tileIds: List<int>.filled(n, 0),
      collision: List<int>.filled(n, 0),
    );
    final layer = TilemapLayerData(
      id: 'tiles_${DateTime.now().millisecondsSinceEpoch}',
      tileW: 32,
      tileH: 32,
      chunks: [chunk],
    );
    scene.tilemaps = List<TilemapLayerData>.from(scene.tilemaps)..add(layer);
    tileLayerIndex = scene.tilemaps.length - 1;
    scene.modifiedAt = DateTime.now();
    _bumpTileEditorRevision();
    notifyListeners();
  }

  void setShowRoomZones(bool v) {
    if (showRoomZones == v) return;
    showRoomZones = v;
    notifyListeners();
  }

  void setShowSceneGrid(bool v) {
    if (showSceneGrid == v) return;
    showSceneGrid = v;
    notifyListeners();
  }

  void setShowTileCollisionPreview(bool v) {
    if (showTileCollisionPreview == v) return;
    showTileCollisionPreview = v;
    _bumpTileEditorRevision();
    notifyListeners();
  }

  void replaceSceneRooms(List<RoomZoneData> rooms) {
    if (_currentScene == null) return;
    pushUndoSnapshot();
    _currentScene!.rooms = List<RoomZoneData>.from(rooms);
    _currentScene!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  void removeObject(String objectId) {
    if (_currentScene == null) return;
    pushUndoSnapshot();
    final List<SceneObject> updatedObjects =
        _currentScene!.objects.where((o) => o.id != objectId).toList();
    _currentScene!.objects = updatedObjects;
    _currentScene!.modifiedAt = DateTime.now();
    if (_selectedObjectId == objectId) {
      _selectedObjectId = null;
    }
    notifyListeners();
  }
}
