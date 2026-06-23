import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'collab/collab_presence.dart';
import 'collab/scene_collab_crdt.dart';
import 'collab/script_studio_presence.dart';
import '../plugins/lynx_plugin_contract.dart';
import '../plugins/lynx_plugin_host.dart';
import 'models/engine_models.dart';
import 'providers/scene_provider.dart';

class ProjectNode {
  final String id;
  final String name;
  final String type;
  final String path;
  final List<ProjectNode> children;
  bool isExpanded;

  ProjectNode({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    this.children = const [],
    this.isExpanded = false,
  });
}

class ProjectManager extends ChangeNotifier {
  String? _rootPath;
  GameProject? _projectSettings;
  final List<ProjectAsset> _assets = [];
  final List<Scene> _scenes = [];
  final List<PrefabDefinition> _prefabs = [];
  ProjectNode? _treeRoot;
  final Set<String> _indexedAssetFolders = {};
  Timer? _saveTimer;
  SceneProvider? _sceneProvider;
  bool _cloudReadOnly = false;
  Dio? _cloudSyncDio;
  String? _cloudSyncConflictMessage;

  WebSocketChannel? _sceneCollabChannel;
  StreamSubscription<dynamic>? _sceneCollabSub;
  String? _collabUserId;
  String? _collabProjectId;
  String? _collabSceneId;
  Map<String, dynamic>? _lastCollabSceneContent;
  int _collabLogicalCounter = 0;
  final Map<String, CollabRemotePointer> _collabRemoteByUser = {};
  int _collabPresenceRevision = 0;
  final Map<String, Set<String>> _hierarchyCollapsedBySceneId = {};
  bool _collabNeedsHierarchyBroadcast = false;

  Dio? _cloudApiDio;
  final Map<String, String> _cloudAssetIdByPath = {};
  WebSocketChannel? _studioCollabChannel;
  StreamSubscription<dynamic>? _studioCollabSub;
  String? _studioCollabUserId;
  String? _studioCollabProjectId;
  final Map<String, ScriptStudioRemote> _scriptStudioRemoteByUser = {};
  final Map<String, int> _studioAssetRemoteRevision = {};
  int _studioRevisionSeq = 0;
  bool _cloudAssetMutationBusy = false;
  String? _cloudAssetMutationMessage;

  String? get rootPath => _rootPath;
  bool get isCloudReadOnly => _cloudReadOnly;
  String? get cloudSyncConflictMessage => _cloudSyncConflictMessage;
  GameProject? get projectSettings => _projectSettings;
  List<ProjectAsset> get assets => _assets;
  List<Scene> get scenes => _scenes;
  List<PrefabDefinition> get prefabs => List.unmodifiable(_prefabs);

  PrefabDefinition? prefabById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in _prefabs) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProjectNode? get treeRoot => _treeRoot;

  bool get hasActiveSceneCollab => _sceneCollabChannel != null;

  int get collabPresenceRevision => _collabPresenceRevision;

  Map<String, CollabRemotePointer> get collabRemotePointers =>
      Map<String, CollabRemotePointer>.unmodifiable(_collabRemoteByUser);

  bool get hasCloudProjectSession => _cloudApiDio != null;

  bool get canPushCloudAsset =>
      _cloudSyncDio != null && !_cloudReadOnly && (_projectSettings?.projectId.isNotEmpty ?? false);

  int studioAssetRefreshRevision(String? cloudAssetId) {
    if (cloudAssetId == null || cloudAssetId.isEmpty) return 0;
    return _studioAssetRemoteRevision[cloudAssetId] ?? 0;
  }

  bool get cloudAssetMutationBusy => _cloudAssetMutationBusy;

  String? get cloudAssetMutationMessage => _cloudAssetMutationMessage;

  Map<String, ScriptStudioRemote> scriptStudioRemotesForCloudAsset(String cloudAssetId) {
    final out = <String, ScriptStudioRemote>{};
    for (final e in _scriptStudioRemoteByUser.entries) {
      if (e.value.cloudAssetId == cloudAssetId) {
        out[e.key] = e.value;
      }
    }
    return Map<String, ScriptStudioRemote>.unmodifiable(out);
  }

  String _normAssetRel(String p) => p.replaceAll('\\', '/');

  String? cloudAssetIdForProjectAssetId(String projectAssetId) {
    if (_cloudAssetIdByPath.isEmpty) return null;
    for (final a in _assets) {
      if (a.id == projectAssetId) {
        return _cloudAssetIdByPath[_normAssetRel(a.path)];
      }
    }
    return null;
  }

  void sendStudioScriptPresence({
    required String cloudAssetId,
    int? line,
    int? column,
    String? displayName,
  }) {
    final ch = _studioCollabChannel;
    final uid = _studioCollabUserId;
    if (ch == null || uid == null) return;
    try {
      final payload = <String, dynamic>{
        'type': 'nexus_script_presence',
        'projectId': _studioCollabProjectId,
        'fromUserId': uid,
        'assetId': cloudAssetId,
        'line': line ?? 0,
        'column': column ?? 0,
      };
      final dn = displayName?.trim();
      if (dn != null && dn.isNotEmpty) {
        payload['displayName'] = dn;
      }
      ch.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  Future<bool> pushCloudAssetContent(String cloudAssetId, Uint8List bytes) async {
    final dio = _cloudSyncDio;
    final pid = _projectSettings?.projectId;
    if (dio == null || pid == null || pid.isEmpty || _cloudReadOnly) return false;
    try {
      final res = await dio.put(
        '/projects/$pid/assets/$cloudAssetId/content',
        data: bytes,
        options: Options(
          contentType: 'application/octet-stream',
          headers: {'Content-Type': 'application/octet-stream'},
        ),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('pushCloudAssetContent: $e');
      return false;
    }
  }

  Future<String?> ensureCloudIdForLocalAsset(String projectAssetId) async {
    if (!canPushCloudAsset || _rootPath == null) return null;
    final existing = cloudAssetIdForProjectAssetId(projectAssetId);
    if (existing != null) return existing;
    final idx = _assets.indexWhere((a) => a.id == projectAssetId);
    if (idx < 0) return null;
    final a = _assets[idx];
    if (a.type != 'script' && a.type != 'sprite' && a.type != 'sound') return null;
    if (_cloudAssetMutationBusy) return cloudAssetIdForProjectAssetId(projectAssetId);
    final file = File(path.join(_rootPath!, a.path));
    if (!await file.exists()) return null;
    _cloudAssetMutationBusy = true;
    _cloudAssetMutationMessage = 'Копирование «${a.name}» на сервер…';
    notifyListeners();
    try {
      final baseName = path.basename(a.path);
      final nameForServer = path.basenameWithoutExtension(baseName);
      final Uint8List bytes;
      final String filename;
      if (a.type == 'script') {
        bytes = Uint8List.fromList(utf8.encode(await file.readAsString()));
        filename = baseName.toLowerCase().endsWith('.lua') ? baseName : '$baseName.lua';
      } else if (a.type == 'sprite') {
        bytes = await file.readAsBytes();
        filename = baseName.toLowerCase().endsWith('.png') ? baseName : '$baseName.png';
      } else if (a.type == 'sound') {
        bytes = await file.readAsBytes();
        filename = baseName;
      } else {
        return null;
      }
      final id = await _postCloudMultipartAsset(
        displayName: nameForServer.isEmpty ? 'asset' : nameForServer,
        assetType: a.type,
        filename: filename,
        bytes: bytes,
      );
      if (id == null || id.isEmpty) return null;
      final rel = _normAssetRel(a.path);
      _cloudAssetIdByPath[rel] = id;
      await _saveCloudAssetMapToSupport();
      _bumpStudioAssetRefresh(id);
      _sendStudioPeerAssetMap(rel, id, a.type);
      notifyListeners();
      return id;
    } catch (e, st) {
      debugPrint('ensureCloudIdForLocalAsset: $e\n$st');
      return null;
    } finally {
      _cloudAssetMutationBusy = false;
      _cloudAssetMutationMessage = null;
      notifyListeners();
    }
  }

  Future<String?> _postCloudMultipartAsset({
    required String displayName,
    required String assetType,
    required String filename,
    required Uint8List bytes,
  }) async {
    final dio = _cloudSyncDio;
    final pid = _projectSettings?.projectId;
    if (dio == null || pid == null || pid.isEmpty) return null;
    try {
      final form = FormData.fromMap({
        'name': displayName,
        'type': assetType,
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final res = await dio.post<dynamic>('/projects/$pid/assets', data: form);
      if (res.statusCode != 200 || res.data == null) return null;
      final data = res.data;
      if (data is! Map) return null;
      return data['id']?.toString();
    } catch (e) {
      debugPrint('_postCloudMultipartAsset: $e');
      return null;
    }
  }

  Future<void> _saveCloudAssetMapToSupport() async {
    final pid = _projectSettings?.projectId;
    if (pid == null || pid.isEmpty) return;
    try {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(path.join(support.path, 'nexus_cloud_maps'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final f = File(path.join(dir.path, '$pid.json'));
      final enc = <String, String>{};
      for (final e in _cloudAssetIdByPath.entries) {
        enc[e.key] = e.value;
      }
      await f.writeAsString(jsonEncode(enc));
    } catch (e) {
      debugPrint('_saveCloudAssetMapToSupport: $e');
    }
  }

  Future<void> _mergeCloudAssetMapFromSupport(String projectId) async {
    try {
      final support = await getApplicationSupportDirectory();
      final f = File(path.join(support.path, 'nexus_cloud_maps', '$projectId.json'));
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final e in j.entries) {
        final k = _normAssetRel(e.key.toString());
        if (!_cloudAssetIdByPath.containsKey(k)) {
          _cloudAssetIdByPath[k] = e.value.toString();
        }
      }
    } catch (e) {
      debugPrint('_mergeCloudAssetMapFromSupport: $e');
    }
  }

  void _sendStudioPeerAssetMap(String relativePathNorm, String cloudAssetId, String assetType) {
    final ch = _studioCollabChannel;
    final uid = _studioCollabUserId;
    if (ch == null || uid == null) return;
    try {
      ch.sink.add(jsonEncode({
        'type': 'nexus_peer_asset_map',
        'fromUserId': uid,
        'relativePath': relativePathNorm,
        'cloudAssetId': cloudAssetId,
        'assetType': assetType,
      }));
    } catch (_) {}
  }

  Future<bool> syncLocalAssetBytesToCloud(String projectAssetId, Uint8List bytes) async {
    var id = cloudAssetIdForProjectAssetId(projectAssetId);
    id ??= await ensureCloudIdForLocalAsset(projectAssetId);
    if (id == null) return false;
    return pushCloudAssetContent(id, bytes);
  }

  bool isHierarchyNodeCollapsed(String sceneId, String parentObjectId) =>
      (_hierarchyCollapsedBySceneId[sceneId] ?? const {}).contains(parentObjectId);

  void toggleHierarchyNodeCollapsed(
    String sceneId,
    String parentObjectId, {
    String? displayName,
    double? cursorX,
    double? cursorY,
    String? selectedObjectId,
  }) {
    final s = _hierarchyCollapsedBySceneId.putIfAbsent(sceneId, () => {});
    if (s.contains(parentObjectId)) {
      s.remove(parentObjectId);
    } else {
      s.add(parentObjectId);
    }
    notifyListeners();
    sendCollabPresence(
      sceneId: sceneId,
      x: cursorX,
      y: cursorY,
      selectedObjectId: selectedObjectId,
      displayName: displayName,
      sendHierarchy: true,
    );
  }

  void sendCollabPresence({
    required String sceneId,
    double? x,
    double? y,
    String? selectedObjectId,
    String? displayName,
    bool sendHierarchy = false,
  }) {
    final ch = _sceneCollabChannel;
    final uid = _collabUserId;
    if (ch == null || uid == null) return;
    if (_collabSceneId != sceneId) return;
    final includeHierarchy = sendHierarchy || _collabNeedsHierarchyBroadcast;
    if (includeHierarchy) {
      _collabNeedsHierarchyBroadcast = false;
    }
    try {
      final payload = <String, dynamic>{
        'type': 'nexus_presence',
        'sceneId': sceneId,
        'fromUserId': uid,
        'cursor': {'x': x, 'y': y},
        'selectedObjectId': selectedObjectId,
      };
      final dn = displayName?.trim();
      if (dn != null && dn.isNotEmpty) {
        payload['displayName'] = dn;
      }
      if (includeHierarchy) {
        payload['hierarchyCollapsed'] =
            (_hierarchyCollapsedBySceneId[sceneId] ?? {}).toList();
      }
      ch.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void setSceneProvider(SceneProvider provider) {
    _sceneProvider = provider;
  }

  Scene? sceneById(String id) {
    for (final s in _scenes) {
      if (s.id == id) return s;
    }
    return null;
  }

  void replaceSceneById(Scene replacement) {
    final i = _scenes.indexWhere((s) => s.id == replacement.id);
    if (i < 0) return;
    _scenes[i] = replacement;
    notifyListeners();
  }

  String _spriteMetaRelativePath(String assetRelativePath) {
    final dir = path.dirname(assetRelativePath);
    final base = path.basenameWithoutExtension(assetRelativePath);
    return path.join(dir, '$base.meta.json');
  }

  Future<void> _writeSpriteMeta(String assetRelativePath, SpriteAssetMeta meta) async {
    if (_rootPath == null) return;
    final metaPath = path.join(_rootPath!, _spriteMetaRelativePath(assetRelativePath));
    final file = File(metaPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(meta.toJson()));
  }

  Future<SpriteAssetMeta?> _readSpriteMeta(String assetRelativePath) async {
    if (_rootPath == null) return null;
    final metaPath = path.join(_rootPath!, _spriteMetaRelativePath(assetRelativePath));
    final file = File(metaPath);
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SpriteAssetMeta.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  /// Meta спрайта по id ассета (волна 5a AnimationPlayer).
  Future<SpriteAssetMeta?> readSpriteMetaForAssetId(String assetId) async {
    for (final a in assets) {
      if (a.id == assetId) {
        return _readSpriteMeta(a.path) ?? a.spriteMeta;
      }
    }
    return null;
  }

  Future<void> _loadProjectFile() async {
    if (_rootPath == null) return;
    final file = File(path.join(_rootPath!, 'project.json'));
    if (await file.exists()) {
      try {
        final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        _projectSettings = GameProject.fromJson(j);
        if (_projectSettings!.projectId.isEmpty) {
          _projectSettings = GameProject(
            projectId: generateProjectUuid(),
            displayName: _projectSettings!.displayName,
            startupSceneId: _projectSettings!.startupSceneId,
            designWidth: _projectSettings!.designWidth,
            designHeight: _projectSettings!.designHeight,
            pixelPerfect: _projectSettings!.pixelPerfect,
            defaultGravityY: _projectSettings!.defaultGravityY,
            pixelsPerUnit: _projectSettings!.pixelsPerUnit,
            physicsLayers: _projectSettings!.physicsLayers,
            inputMap: _projectSettings!.inputMap,
            tilesets: _projectSettings!.tilesets,
            audioMasterVolume: _projectSettings!.audioMasterVolume,
            audioBusVolumes: _projectSettings!.audioBusVolumes,
          );
          await file.writeAsString(jsonEncode(_projectSettings!.toJson()));
        }
      } catch (_) {
        _projectSettings = GameProject.fresh(displayName: path.basename(_rootPath!));
        await file.writeAsString(jsonEncode(_projectSettings!.toJson()));
      }
    } else {
      _projectSettings = GameProject.fresh(displayName: path.basename(_rootPath!));
      await file.writeAsString(jsonEncode(_projectSettings!.toJson()));
    }
  }

  Future<void> saveProjectSettings(GameProject settings) async {
    if (_cloudReadOnly) return;
    if (_rootPath == null) return;
    _projectSettings = settings;
    final file = File(path.join(_rootPath!, 'project.json'));
    await file.writeAsString(jsonEncode(settings.toJson()));
    await _openPluginHost();
    final scene = _sceneProvider?.currentScene;
    if (scene != null) {
      LynxPluginHost.instance.applySceneExtensions(scene);
      _sceneProvider?.notifyListeners();
    }
    notifyListeners();
  }

  bool isAssetPathDisabled(String relativePath) {
    final norm = relativePath.replaceAll('\\', '/');
    return _projectSettings?.lynxPlugins.disabledAssetPaths.contains(norm) ?? false;
  }

  Future<void> setAssetPathEnabled(String relativePath, bool enabled) async {
    final settings = _projectSettings;
    if (settings == null || _rootPath == null || _cloudReadOnly) return;
    final norm = relativePath.replaceAll('\\', '/');
    final disabled = List<String>.from(settings.lynxPlugins.disabledAssetPaths);
    if (enabled) {
      disabled.remove(norm);
    } else if (!disabled.contains(norm)) {
      disabled.add(norm);
    }
    await saveProjectSettings(
      settings.copyWith(
        lynxPlugins: settings.lynxPlugins.copyWith(disabledAssetPaths: disabled),
      ),
    );
  }

  void scheduleSceneSave() {
    if (_cloudReadOnly) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), _performSave);
  }

  Future<void> _performSave() async {
    if (_cloudReadOnly) return;
    if (_rootPath == null || _sceneProvider == null) return;
    final scene = _sceneProvider!.currentScene;
    if (scene == null) return;
    await _saveScene(scene);
  }

  Future<void> _saveScene(Scene scene) async {
    if (_cloudReadOnly) return;
    if (_rootPath == null) return;
    scene.bumpRevision();
    final filePath = path.join(_rootPath!, 'scenes', '${scene.id}.json');
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(scene.toJson()));
    notifyListeners();
    await _pushSceneToCloud(scene);
  }

  Future<void> _pushSceneToCloud(Scene scene) async {
    final dio = _cloudSyncDio;
    final pid = _projectSettings?.projectId;
    if (dio == null || pid == null || pid.isEmpty) return;
    try {
      final payload = Map<String, dynamic>.from(scene.toJson());
      payload.remove('cloudRevision');
      final res = await dio.put(
        '/projects/$pid/scenes/${scene.id}',
        data: {
          'content': payload,
          'base_revision': scene.cloudRevision ?? 0,
        },
      );
      if (res.statusCode == 200 && res.data is Map) {
        final body = res.data as Map;
        final rev = (body['revision'] as num?)?.toInt();
        if (rev != null) scene.cloudRevision = rev;
        _cloudSyncConflictMessage = null;
        notifyListeners();
        _broadcastSceneCollab(scene);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _cloudSyncConflictMessage =
            'Сцена «${scene.name}» изменена на сервере. Сохраните копию (экспорт) и перезагрузите проект.';
      } else {
        _cloudSyncConflictMessage =
            e.response?.data is Map ? _apiErrorRaw(e.response?.data) : (e.message ?? 'Ошибка синхронизации');
      }
      notifyListeners();
    } catch (e) {
      _cloudSyncConflictMessage = e.toString();
      notifyListeners();
    }
  }

  String? _apiErrorRaw(dynamic data) {
    if (data is Map && data['error'] != null) return data['error'].toString();
    return null;
  }

  Future<void> saveCurrentSceneManually() async {
    if (_cloudReadOnly) return;
    if (_sceneProvider == null) return;
    final scene = _sceneProvider!.currentScene;
    if (scene != null) {
      await _saveScene(scene);
    }
  }

  Future<bool> loadProject(String projectPath) async {
    await LynxPluginHost.instance.closeProject();
    disposeSceneCollaboration();
    disposeStudioCollaboration();
    _hierarchyCollapsedBySceneId.clear();
    _cloudAssetIdByPath.clear();
    _cloudApiDio = null;
    _cloudReadOnly = false;
    _cloudSyncDio = null;
    _cloudSyncConflictMessage = null;
    _rootPath = projectPath;
    await _loadProjectFile();
    await _loadAssets();
    await _reindexAssetFolders();
    await _loadPrefabs();
    await _loadScenes();
    await _openPluginHost();
    _buildTree();
    notifyListeners();
    return true;
  }

  Future<void> _openPluginHost() async {
    final settings = _projectSettings;
    if (_rootPath == null || settings == null) return;
    await LynxPluginHost.instance.openProject(
      LynxPluginProjectContext(
        projectRoot: _rootPath,
        projectMode: settings.projectMode,
        plugins: settings.lynxPlugins,
        displayName: settings.displayName,
      ),
    );
  }

  Future<void> _loadPrefabs() async {
    _prefabs.clear();
    if (_rootPath == null) return;
    final dir = Directory(path.join(_rootPath!, 'prefabs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      return;
    }
    await for (final entity in dir.list()) {
      if (entity is! File || path.extension(entity.path) != '.json') continue;
      try {
        final raw = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        _prefabs.add(PrefabDefinition.fromJson(raw));
      } catch (e) {
        debugPrint('Prefab load error ${entity.path}: $e');
      }
    }
  }

  Future<void> _loadAssets() async {
    _assets.clear();
    final assetsDir = Directory('$_rootPath/assets');
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
      return;
    }
    final List<FileSystemEntity> entities = await assetsDir.list(recursive: true).toList();
    for (final entity in entities) {
      if (entity is File) {
        final baseName = path.basename(entity.path);
        if (baseName.endsWith('.meta.json') || baseName.endsWith('.lynxdoc.json')) continue;
        final relativePath = path.relative(entity.path, from: _rootPath);
        final ext = path.extension(entity.path).toLowerCase();
        String type;
        if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
          type = 'sprite';
        } else if (ext == '.lua' || ext == '.lynxscript') {
          type = 'script';
        } else if (ext == '.mp3' || ext == '.wav') {
          type = 'sound';
        } else if (ext == '.glb' || ext == '.gltf') {
          type = 'model';
        } else {
          continue;
        }
        final meta = type == 'sprite' ? await _readSpriteMeta(relativePath) : null;
        _assets.add(ProjectAsset(
          id: relativePath.replaceAll('/', '_').replaceAll('\\', '_'),
          name: baseName,
          type: type,
          path: relativePath,
          createdAt: await entity.lastAccessed(),
          modifiedAt: await entity.lastModified(),
          spriteMeta: meta,
        ));
      }
    }
  }

  Scene _newDefaultScene({String id = 'main', String name = 'Main Scene'}) {
    final now = DateTime.now();
    return Scene(
      id: id,
      name: name,
      layers: Scene.defaultLayers(),
      createdAt: now,
      modifiedAt: now,
    );
  }

  Future<void> _loadScenes() async {
    _scenes.clear();
    final scenesDir = Directory('$_rootPath/scenes');
    if (!await scenesDir.exists()) {
      await scenesDir.create(recursive: true);
      final defaultScene = _newDefaultScene();
      _scenes.add(defaultScene);
      await _saveSceneWithoutRevisionBump(defaultScene);
      return;
    }
    final List<FileSystemEntity> entities = await scenesDir.list().toList();
    for (final entity in entities) {
      if (entity is File) {
        if (path.extension(entity.path) != '.json') {
          continue;
        }
        try {
          final content = await entity.readAsString();
          if (content.isEmpty) {
            debugPrint('Scene file ${entity.path} is empty');
            continue;
          }
          final Map<String, dynamic> jsonData = jsonDecode(content);
          final scene = Scene.fromJson(jsonData);
          _scenes.add(scene);
          debugPrint('Loaded scene: ${scene.name} with ${scene.objects.length} objects');
        } catch (e) {
          debugPrint('Error loading scene ${entity.path}: $e');
          if (entity.path.contains('main.json')) {
            final defaultScene = _newDefaultScene();
            _scenes.add(defaultScene);
            await _saveSceneWithoutRevisionBump(defaultScene);
          }
        }
      }
    }
    if (_scenes.isEmpty) {
      final defaultScene = _newDefaultScene();
      _scenes.add(defaultScene);
      await _saveSceneWithoutRevisionBump(defaultScene);
    }
  }

  Future<void> _saveSceneWithoutRevisionBump(Scene scene) async {
    if (_rootPath == null) return;
    final filePath = path.join(_rootPath!, 'scenes', '${scene.id}.json');
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(scene.toJson()));
  }

  void _buildTree() {
    _treeRoot = ProjectNode(
      id: 'root',
      name: path.basename(_rootPath!),
      type: 'folder',
      path: '',
      children: [],
    );
    final Map<String, ProjectNode> folders = {};
    folders[''] = _treeRoot!;
    for (final asset in _assets) {
      final parts = path.split(asset.path);
      if (parts.isEmpty) continue;
      final partsCopy = List<String>.from(parts);
      final fileName = partsCopy.removeLast();
      final folderPath = partsCopy.join(Platform.pathSeparator);
      if (!folders.containsKey(folderPath)) {
        final newNode = ProjectNode(
          id: 'folder_$folderPath',
          name: partsCopy.isEmpty ? 'assets' : partsCopy.last,
          type: 'folder',
          path: folderPath,
          children: [],
        );
        folders[folderPath] = newNode;
        if (folderPath.isNotEmpty) {
          final parentPath = path.dirname(folderPath);
          folders[parentPath]?.children.add(newNode);
        } else {
          _treeRoot!.children.add(newNode);
        }
      }
      folders[folderPath]!.children.add(ProjectNode(
        id: asset.id,
        name: fileName,
        type: asset.type,
        path: asset.path,
        children: [],
      ));
    }
    final prefabFolder = ProjectNode(
      id: 'folder_prefabs',
      name: 'prefabs',
      type: 'folder',
      path: 'prefabs',
      children: _prefabs
          .map((p) => ProjectNode(
                id: 'prefab_${p.id}',
                name: '${p.name}.json',
                type: 'prefab',
                path: 'prefabs/${p.id}.json',
                children: [],
              ))
          .toList(),
    );
    _treeRoot!.children.add(prefabFolder);
    for (final scene in _scenes) {
      _treeRoot!.children.add(ProjectNode(
        id: 'scene_${scene.id}',
        name: '${scene.name}.json',
        type: 'scene',
        path: 'scenes/${scene.id}.json',
        children: [],
      ));
    }
    _injectEmptyAssetFolders();
  }

  Future<void> _reindexAssetFolders() async {
    _indexedAssetFolders.clear();
    if (_rootPath == null) return;
    final root = path.join(_rootPath!, 'assets');
    final d = Directory(root);
    if (!await d.exists()) return;
    await for (final e in d.list(recursive: true)) {
      if (e is Directory) {
        _indexedAssetFolders.add(path.relative(e.path, from: _rootPath!));
      }
    }
  }

  void _injectEmptyAssetFolders() {
    if (_treeRoot == null) return;
    final sorted = _indexedAssetFolders.toList()
      ..sort((a, b) {
        final da = a.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).length;
        final db = b.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).length;
        if (da != db) return da.compareTo(db);
        return a.replaceAll('\\', '/').compareTo(b.replaceAll('\\', '/'));
      });
    for (final raw in sorted) {
      final norm = raw.replaceAll('\\', '/');
      if (!norm.startsWith('assets/') && norm != 'assets') continue;
      final parts = norm.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) continue;
      _ensureFolderChainUnderRoot(parts);
    }
  }

  void _ensureFolderChainUnderRoot(List<String> parts) {
    ProjectNode parent = _treeRoot!;
    final acc = <String>[];
    for (final seg in parts) {
      acc.add(seg);
      ProjectNode? found;
      for (final c in parent.children) {
        if (c.type == 'folder' && c.name == seg) {
          found = c;
          break;
        }
      }
      if (found == null) {
        final pathStr = acc.join(Platform.pathSeparator);
        found = ProjectNode(
          id: 'folder_${pathStr.replaceAll(RegExp(r'[/\\]'), '_')}',
          name: seg,
          type: 'folder',
          path: pathStr,
          children: [],
          isExpanded: true,
        );
        parent.children.add(found);
      }
      parent = found;
    }
  }

  Future<String?> createAssetFolder(String pathUnderAssets) async {
    if (_cloudReadOnly) return 'Режим только чтения';
    if (_rootPath == null) return 'Проект не загружен';
    final segs = pathUnderAssets
        .replaceAll('\\', '/')
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '.' && e != '..')
        .toList();
    if (segs.isEmpty) return 'Укажите имя папки';
    final rel = path.join('assets', path.joinAll(segs));
    try {
      await Directory(path.join(_rootPath!, rel)).create(recursive: true);
      await _loadAssets();
      await _reindexAssetFolders();
      _buildTree();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> refreshFilesystemIndex() async {
    if (_rootPath == null) return;
    await _loadAssets();
    await _loadPrefabs();
    await _reindexAssetFolders();
    _buildTree();
    notifyListeners();
  }

  Future<void> refreshAssetTree() => refreshFilesystemIndex();

  Future<ProjectAsset?> createSprite(
    String name,
    Uint8List bytes, {
    List<String> pathSegments = const [],
  }) async {
    if (_cloudReadOnly) return null;
    if (_rootPath == null) return null;
    final fileName = name.endsWith('.png') ? name : '$name.png';
    final dir = pathSegments.isEmpty
        ? path.join('assets', 'sprites')
        : path.join('assets', 'sprites', path.joinAll(pathSegments));
    final rel = path.join(dir, fileName);
    final file = File(path.join(_rootPath!, rel));
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    const meta = SpriteAssetMeta();
    await _writeSpriteMeta(rel, meta);
    final asset = ProjectAsset(
      id: rel.replaceAll('/', '_').replaceAll('\\', '_'),
      name: fileName,
      type: 'sprite',
      path: rel,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      data: bytes,
      spriteMeta: meta,
    );
    _assets.add(asset);
    _buildTree();
    notifyListeners();
    return asset;
  }

  Future<void> reloadSpriteAsset(String assetId) async {
    if (_cloudReadOnly) return;
    if (_rootPath == null) return;
    final idx = _assets.indexWhere((a) => a.id == assetId);
    if (idx < 0) return;
    final a = _assets[idx];
    if (a.type != 'sprite') return;
    final f = File(path.join(_rootPath!, a.path));
    if (!await f.exists()) return;
    final bytes = await f.readAsBytes();
    final meta = await _readSpriteMeta(a.path) ?? a.spriteMeta;
    _assets[idx] = ProjectAsset(
      id: a.id,
      name: a.name,
      type: a.type,
      path: a.path,
      createdAt: a.createdAt,
      modifiedAt: await f.lastModified(),
      data: bytes,
      spriteMeta: meta,
    );
    notifyListeners();
  }

  Future<void> updateSpriteMeta(String assetId, SpriteAssetMeta meta) async {
    if (_cloudReadOnly) return;
    final idx = _assets.indexWhere((a) => a.id == assetId);
    if (idx < 0) return;
    final asset = _assets[idx];
    if (asset.type != 'sprite') return;
    await _writeSpriteMeta(asset.path, meta);
    _assets[idx] = ProjectAsset(
      id: asset.id,
      name: asset.name,
      type: asset.type,
      path: asset.path,
      createdAt: asset.createdAt,
      modifiedAt: DateTime.now(),
      data: asset.data,
      spriteMeta: meta,
    );
    notifyListeners();
  }

  Future<ProjectAsset?> createScript(
    String name,
    String content, {
    List<String> pathSegments = const [],
  }) async {
    if (_cloudReadOnly) return null;
    if (_rootPath == null) return null;
    final fileName = name.endsWith('.lua') ? name : '$name.lua';
    final dir = pathSegments.isEmpty
        ? path.join('assets', 'scripts')
        : path.join('assets', 'scripts', path.joinAll(pathSegments));
    final rel = path.join(dir, fileName);
    final filePath = path.join(_rootPath!, rel);
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(content);
    final asset = ProjectAsset(
      id: rel.replaceAll('/', '_').replaceAll('\\', '_'),
      name: fileName,
      type: 'script',
      path: rel,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      data: content,
    );
    _assets.add(asset);
    _buildTree();
    notifyListeners();
    return asset;
  }

  Future<ProjectAsset?> createLynxScriptAsset(
    String name,
    String lynxScriptContent, {
    Map<String, dynamic>? graphJson,
  }) async {
    if (_cloudReadOnly) return null;
    if (_rootPath == null) return null;
    final safe = name.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final fileName = safe.endsWith('.lynxscript') ? safe : '$safe.lynxscript';
    final rel = path.join('assets', 'scripts', fileName);
    final filePath = path.join(_rootPath!, rel);
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(lynxScriptContent);
    if (graphJson != null) {
      final graphRel = '$rel.graph.json';
      await File(path.join(_rootPath!, graphRel)).writeAsString(
        const JsonEncoder.withIndent('  ').convert(graphJson),
      );
    }
    final asset = ProjectAsset(
      id: rel.replaceAll('/', '_').replaceAll('\\', '_'),
      name: fileName,
      type: 'script',
      path: rel,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      data: lynxScriptContent,
    );
    final existing = _assets.indexWhere((a) => a.id == asset.id);
    if (existing >= 0) {
      _assets[existing] = asset;
    } else {
      _assets.add(asset);
    }
    _buildTree();
    notifyListeners();
    return asset;
  }

  Future<ProjectAsset?> importSoundFromFile(String sourcePath, {String? displayName}) async {
    if (_cloudReadOnly) return null;
    if (_rootPath == null) return null;
    final src = File(sourcePath);
    if (!await src.exists()) return null;
    final base = displayName ?? path.basename(sourcePath);
    var fileName = base;
    if (!RegExp(r'\.(wav|mp3|ogg|m4a)$', caseSensitive: false).hasMatch(fileName)) {
      fileName = '$fileName.wav';
    }
    final rel = path.join('assets', 'sounds', fileName);
    final dest = File(path.join(_rootPath!, rel));
    await dest.parent.create(recursive: true);
    await src.copy(dest.path);
    final asset = ProjectAsset(
      id: rel.replaceAll('/', '_').replaceAll('\\', '_'),
      name: fileName,
      type: 'sound',
      path: rel,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    final existing = _assets.indexWhere((a) => a.id == asset.id);
    if (existing >= 0) {
      _assets[existing] = asset;
    } else {
      _assets.add(asset);
    }
    _buildTree();
    notifyListeners();
    return asset;
  }

  Future<String?> replaceSoundAssetFile(String assetId, String sourcePath) async {
    if (_cloudReadOnly) return 'Только чтение';
    if (_rootPath == null) return 'Нет проекта';
    final idx = _assets.indexWhere((a) => a.id == assetId);
    if (idx < 0) return 'Ассет не найден';
    final a = _assets[idx];
    if (a.type != 'sound') return 'Не звуковой ассет';
    final src = File(sourcePath);
    if (!await src.exists()) return 'Файл не найден';
    final dest = File(path.join(_rootPath!, a.path));
    await dest.parent.create(recursive: true);
    await src.copy(dest.path);
    _assets[idx] = ProjectAsset(
      id: a.id,
      name: a.name,
      type: a.type,
      path: a.path,
      createdAt: a.createdAt,
      modifiedAt: DateTime.now(),
    );
    if (canPushCloudAsset) {
      final bytes = await dest.readAsBytes();
      await syncLocalAssetBytesToCloud(assetId, bytes);
    }
    notifyListeners();
    return null;
  }

  void updateScriptAssetContent(String assetId, String content) {
    final idx = _assets.indexWhere((a) => a.id == assetId);
    if (idx < 0) return;
    final prev = _assets[idx];
    _assets[idx] = ProjectAsset(
      id: prev.id,
      name: prev.name,
      type: prev.type,
      path: prev.path,
      createdAt: prev.createdAt,
      modifiedAt: DateTime.now(),
      data: content,
    );
    notifyListeners();
  }

  Future<Scene> createScene(String name) async {
    if (_cloudReadOnly) {
      throw StateError('read-only cloud project');
    }
    final scene = Scene(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      layers: Scene.defaultLayers(),
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
    _scenes.add(scene);
    await _saveSceneWithoutRevisionBump(scene);
    _buildTree();
    notifyListeners();
    return scene;
  }

  Future<PrefabDefinition?> savePrefab({
    required String prefabName,
    required SceneObject templateRoot,
  }) async {
    if (_cloudReadOnly) return null;
    if (_rootPath == null) return null;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final def = PrefabDefinition(
      id: id,
      name: prefabName,
      templateRoot: templateRoot.copyWith(prefabId: null),
    );
    final dir = Directory(path.join(_rootPath!, 'prefabs'));
    await dir.create(recursive: true);
    final file = File(path.join(dir.path, '$id.json'));
    await file.writeAsString(jsonEncode(def.toJson()));
    _prefabs.add(def);
    _buildTree();
    notifyListeners();
    return def;
  }

  Future<PrefabDefinition?> savePrefabFromHierarchy({
    required String prefabName,
    required Scene scene,
    required SceneObject root,
  }) async {
    if (_cloudReadOnly) return null;
    if (_rootPath == null) return null;
    final ordered = collectSceneSubtreeOrdered(scene, root);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final def = buildPrefabDefinitionFromSceneSubtree(
      id: id,
      name: prefabName,
      ordered: ordered,
    );
    final dir = Directory(path.join(_rootPath!, 'prefabs'));
    await dir.create(recursive: true);
    final file = File(path.join(dir.path, '$id.json'));
    await file.writeAsString(jsonEncode(def.toJson()));
    _prefabs.add(def);
    _buildTree();
    notifyListeners();
    return def;
  }

  void instantiatePrefabIntoCurrentScene(PrefabDefinition def, {String? layerId}) {
    if (_sceneProvider?.currentScene == null) return;
    _sceneProvider!.pushUndoSnapshot();
    final batch = instantiateAllFromPrefab(def, layerId: layerId);
    for (var i = 0; i < batch.length; i++) {
      _sceneProvider!.addObject(batch[i], skipUndo: true);
    }
    scheduleSceneSave();
  }

  bool applyRemoteScenePatch(ScenePatch patch) {
    if (_cloudReadOnly) return false;
    final i = _scenes.indexWhere((s) => s.id == patch.sceneId);
    if (i < 0) return false;
    final applied = applyScenePatch(_scenes[i], patch);
    if (applied == null) return false;
    _scenes[i] = applied;
    if (_sceneProvider?.currentScene?.id == applied.id) {
      _sceneProvider!.setCurrentScene(applied);
    }
    notifyListeners();
    return true;
  }

  static String _safeCloudFileName(String name) {
    return name.replaceAll(RegExp(r'''[/\\?\*:|<>"']'''), '_').trim();
  }

  Future<String?> loadCloudProject(
    String projectId,
    Dio http, {
    required String displayName,
    bool readOnly = false,
  }) async {
    _cloudReadOnly = false;
    _cloudSyncDio = null;
    _cloudSyncConflictMessage = null;
    _saveTimer?.cancel();

    try {
      disposeSceneCollaboration();
      disposeStudioCollaboration();
      _hierarchyCollapsedBySceneId.clear();
      _cloudAssetIdByPath.clear();
      _cloudApiDio = null;
      final support = await getApplicationSupportDirectory();
      final root = path.join(support.path, 'nexus_cloud_cache', projectId);
      final rootDir = Directory(root);
      if (await rootDir.exists()) {
        await rootDir.delete(recursive: true);
      }
      await rootDir.create(recursive: true);

      final res = await http.get('/projects/$projectId/assets');
      if (res.statusCode != 200) {
        final err = res.data is Map ? (res.data as Map)['error']?.toString() : null;
        return err ?? 'Ошибка списка ассетов (${res.statusCode})';
      }
      final list = res.data is List ? res.data as List<dynamic> : <dynamic>[];

      for (final raw in list) {
        if (raw is! Map<String, dynamic>) continue;
        final id = raw['id']?.toString();
        final name = raw['name']?.toString() ?? 'asset';
        final type = raw['type']?.toString() ?? '';
        if (id == null || id.isEmpty) continue;

        final sub = switch (type) {
          'sprite' => 'assets/sprites',
          'script' => 'assets/scripts',
          'sound' => 'assets/sounds',
          _ => '',
        };
        if (sub.isEmpty) continue;

        var base = _safeCloudFileName(name);
        if (base.isEmpty) base = 'file';
        final prefix = id.length >= 8 ? id.substring(0, 8) : id;
        var fileName = '${prefix}_$base';
        if (type == 'sprite' && !fileName.contains('.')) fileName = '$fileName.png';
        if (type == 'script' && !fileName.toLowerCase().endsWith('.lua')) {
          fileName = '$fileName.lua';
        }
        if (type == 'sound' &&
            !RegExp(r'\.(mp3|wav|ogg|m4a)$', caseSensitive: false).hasMatch(fileName)) {
          fileName = '$fileName.wav';
        }

        final bin = await http.get(
          '/assets/$id',
          options: Options(responseType: ResponseType.bytes),
        );
        if (bin.statusCode != 200 || bin.data == null) continue;
        final data = bin.data;
        List<int> bytes;
        if (data is List<int>) {
          bytes = data;
        } else if (data is Uint8List) {
          bytes = data;
        } else {
          continue;
        }
        final out = File(path.join(root, sub, fileName));
        await out.parent.create(recursive: true);
        await out.writeAsBytes(bytes);
        final relNorm = _normAssetRel(path.join(sub, fileName));
        _cloudAssetIdByPath[relNorm] = id;
      }
      await _mergeCloudAssetMapFromSupport(projectId);

      _rootPath = root;
      _projectSettings = GameProject(
        projectId: projectId,
        displayName: displayName,
      );
      await File(path.join(root, 'project.json'))
          .writeAsString(jsonEncode(_projectSettings!.toJson()));

      await _pullCloudScenesIntoCache(projectId, http, root);

      await _loadAssets();
      await _loadPrefabs();
      await _loadScenes();
      _buildTree();
      _cloudReadOnly = readOnly;
      _cloudApiDio = http;
      _cloudSyncDio = readOnly ? null : http;
      await _saveCloudAssetMapToSupport();
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('loadCloudProject error: $e\n$st');
      return e.toString();
    }
  }

  Future<void> _pullCloudScenesIntoCache(String projectId, Dio http, String root) async {
    try {
      final listRes = await http.get('/projects/$projectId/scenes');
      if (listRes.statusCode != 200) return;
      final rawList = listRes.data;
      if (rawList is! List || rawList.isEmpty) return;
      final scenesDir = Directory(path.join(root, 'scenes'));
      await scenesDir.create(recursive: true);
      for (final raw in rawList) {
        if (raw is! Map) continue;
        final sid = raw['scene_id']?.toString();
        if (sid == null || sid.isEmpty) continue;
        final getRes = await http.get('/projects/$projectId/scenes/$sid');
        if (getRes.statusCode != 200 || getRes.data is! Map<String, dynamic>) continue;
        final body = getRes.data as Map<String, dynamic>;
        final content = body['content'];
        if (content is! Map<String, dynamic>) continue;
        final rev = (body['revision'] as num?)?.toInt() ?? 1;
        final scene = Scene.fromJson(content);
        scene.cloudRevision = rev;
        await File(path.join(scenesDir.path, '$sid.json'))
            .writeAsString(jsonEncode(scene.toJson()));
      }
    } catch (e, st) {
      debugPrint('_pullCloudScenesIntoCache: $e\n$st');
    }
  }

  void disposeSceneCollaboration() {
    _sceneCollabSub?.cancel();
    _sceneCollabSub = null;
    _sceneCollabChannel?.sink.close();
    _sceneCollabChannel = null;
    _collabUserId = null;
    _collabProjectId = null;
    _collabSceneId = null;
    _lastCollabSceneContent = null;
    _collabLogicalCounter = 0;
    _collabRemoteByUser.clear();
    _collabNeedsHierarchyBroadcast = false;
    _collabPresenceRevision++;
    notifyListeners();
  }

  void disposeStudioCollaboration() {
    _studioCollabSub?.cancel();
    _studioCollabSub = null;
    _studioCollabChannel?.sink.close();
    _studioCollabChannel = null;
    _studioCollabUserId = null;
    _studioCollabProjectId = null;
    _scriptStudioRemoteByUser.clear();
    notifyListeners();
  }

  Uri _wsUriForStudio(String apiBase, String projectId, String token) {
    final u = Uri.parse(apiBase);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final p = '/ws/projects/$projectId/studio';
    return Uri(
      scheme: scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: p,
      queryParameters: {'access_token': token},
    );
  }

  void _pruneStudioPresence() {
    final now = DateTime.now();
    _scriptStudioRemoteByUser.removeWhere(
      (_, v) => now.difference(v.updatedAt).inSeconds > 60,
    );
  }

  void _onStudioMessage(dynamic raw) {
    final uid = _studioCollabUserId;
    if (uid == null) return;
    late final String s;
    if (raw is String) {
      s = raw;
    } else if (raw is List<int>) {
      s = utf8.decode(raw);
    } else if (raw is Uint8List) {
      s = utf8.decode(raw);
    } else {
      return;
    }
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final ty = m['type']?.toString();
      if (ty == 'nexus_asset_updated') {
        final aid = m['assetId']?.toString();
        if (aid == null || aid.isEmpty) return;
        final by = m['updatedBy']?.toString();
        if (by != null && by == uid) {
          _bumpStudioAssetRefresh(aid);
          notifyListeners();
          return;
        }
        unawaited(_pullRemoteAssetIntoCache(aid).then((_) {
          _bumpStudioAssetRefresh(aid);
          notifyListeners();
        }));
        return;
      }
      if (ty == 'nexus_script_presence') {
        final p = ScriptStudioRemote.tryParse(m);
        if (p == null) return;
        if (p.userId == uid) return;
        _scriptStudioRemoteByUser[p.userId] = p;
        _pruneStudioPresence();
        notifyListeners();
        return;
      }
      if (ty == 'nexus_peer_asset_map') {
        if (m['fromUserId']?.toString() == uid) return;
        final rel = m['relativePath']?.toString();
        final cid = m['cloudAssetId']?.toString();
        if (rel == null || cid == null || cid.isEmpty) return;
        final rk = _normAssetRel(rel);
        _cloudAssetIdByPath[rk] = cid;
        unawaited(_saveCloudAssetMapToSupport().then((_) {
          unawaited(_pullRemoteAssetIntoCache(cid).then((_) {
            _bumpStudioAssetRefresh(cid);
            notifyListeners();
          }));
        }));
        return;
      }
    } catch (e) {
      debugPrint('studio message: $e');
    }
  }

  void _bumpStudioAssetRefresh(String cloudAssetId) {
    _studioRevisionSeq += 1;
    _studioAssetRemoteRevision[cloudAssetId] = _studioRevisionSeq;
  }

  Future<void> _pullRemoteAssetIntoCache(String cloudAssetId) async {
    final dio = _cloudApiDio;
    final root = _rootPath;
    if (dio == null || root == null) return;
    String? relPath;
    for (final e in _cloudAssetIdByPath.entries) {
      if (e.value == cloudAssetId) {
        relPath = e.key;
        break;
      }
    }
    if (relPath == null) return;
    try {
      final res = await dio.get(
        '/assets/$cloudAssetId',
        options: Options(responseType: ResponseType.bytes),
      );
      if (res.statusCode != 200 || res.data == null) return;
      final body = res.data!;
      final bytes = body is Uint8List ? body : Uint8List.fromList(body as List<int>);
      final nrel = _normAssetRel(relPath);
      final existedBefore = _assets.any((a) => _normAssetRel(a.path) == nrel);
      final file = File(path.join(root, relPath));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      await _refreshLoadedAssetAfterCloudPull(relPath, bytes);
      if (!existedBefore) {
        await _loadAssets();
        _buildTree();
      }
    } catch (e) {
      debugPrint('_pullRemoteAssetIntoCache: $e');
    }
  }

  Future<void> _refreshLoadedAssetAfterCloudPull(String relPathNorm, Uint8List bytes) async {
    final n = _normAssetRel(relPathNorm);
    final idx = _assets.indexWhere((a) => _normAssetRel(a.path) == n);
    if (idx < 0) return;
    final a = _assets[idx];
    final file = File(path.join(_rootPath!, a.path));
    DateTime modifiedAt;
    try {
      modifiedAt = await file.lastModified();
    } catch (_) {
      modifiedAt = DateTime.now();
    }
    if (a.type == 'script') {
      final text = utf8.decode(bytes);
      _assets[idx] = ProjectAsset(
        id: a.id,
        name: a.name,
        type: a.type,
        path: a.path,
        createdAt: a.createdAt,
        modifiedAt: modifiedAt,
        data: text,
        spriteMeta: a.spriteMeta,
      );
    } else if (a.type == 'sprite') {
      _assets[idx] = ProjectAsset(
        id: a.id,
        name: a.name,
        type: a.type,
        path: a.path,
        createdAt: a.createdAt,
        modifiedAt: modifiedAt,
        data: bytes,
        spriteMeta: a.spriteMeta,
      );
    }
  }

  void ensureStudioCollaboration({
    required String projectId,
    required String token,
    required String userId,
    required String apiBaseUrl,
  }) {
    if (_cloudApiDio == null || projectId.isEmpty) {
      disposeStudioCollaboration();
      return;
    }
    if (_studioCollabProjectId == projectId &&
        _studioCollabUserId == userId &&
        _studioCollabChannel != null) {
      return;
    }
    disposeStudioCollaboration();
    _studioCollabProjectId = projectId;
    _studioCollabUserId = userId;
    try {
      final uri = _wsUriForStudio(apiBaseUrl, projectId, token);
      final ch = WebSocketChannel.connect(uri);
      _studioCollabChannel = ch;
      _studioCollabSub = ch.stream.listen(
        _onStudioMessage,
        onError: (Object e) => debugPrint('studio stream: $e'),
        onDone: () => debugPrint('studio closed'),
      );
    } catch (e, st) {
      debugPrint('ensureStudioCollaboration: $e\n$st');
    }
  }

  Uri _wsUriForCollab(String apiBase, String projectId, String sceneId, String token) {
    final u = Uri.parse(apiBase);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    final p = '/ws/projects/$projectId/scenes/${Uri.encodeComponent(sceneId)}';
    return Uri(
      scheme: scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
      path: p,
      queryParameters: {'access_token': token},
    );
  }

  void _broadcastSceneCollab(Scene scene) {
    final ch = _sceneCollabChannel;
    final uid = _collabUserId;
    if (ch == null || uid == null) return;
    final payload = Map<String, dynamic>.from(scene.toJson());
    payload.remove('cloudRevision');
    try {
      final ops = buildSceneCrdtOps(
        previous: _lastCollabSceneContent,
        current: payload,
        nextHlc: () {
          _collabLogicalCounter += 1;
          return CollabHlc(
            wallMs: DateTime.now().millisecondsSinceEpoch,
            logical: _collabLogicalCounter,
            site: uid,
          );
        },
      );
      _lastCollabSceneContent = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(payload)) as Map<dynamic, dynamic>,
      );
      if (ops.isNotEmpty) {
        ch.sink.add(jsonEncode({
          'type': 'nexus_scene_crdt',
          'sceneId': scene.id,
          'ops': ops,
        }));
      }
    } catch (e, st) {
      debugPrint('collab crdt: $e\n$st');
    }
    final msg = jsonEncode({
      'type': 'nexus_scene_sync',
      'sceneId': scene.id,
      'fromUserId': uid,
      'revision': scene.cloudRevision,
      'content': payload,
    });
    try {
      ch.sink.add(msg);
    } catch (e) {
      debugPrint('collab broadcast: $e');
    }
  }

  void _onCollabMessage(dynamic raw) {
    final uid = _collabUserId;
    if (uid == null) return;
    late final String s;
    if (raw is String) {
      s = raw;
    } else if (raw is List<int>) {
      s = utf8.decode(raw);
    } else if (raw is Uint8List) {
      s = utf8.decode(raw);
    } else {
      return;
    }
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      final ty = m['type']?.toString();
      if (ty == 'nexus_presence') {
        if (m['fromUserId']?.toString() == uid) return;
        final sceneId = m['sceneId']?.toString() ?? '';
        if (sceneId.isNotEmpty && sceneId != _collabSceneId) return;
        if (m.containsKey('hierarchyCollapsed')) {
          _hierarchyCollapsedBySceneId[sceneId] =
              parseHierarchyCollapsedIds(m['hierarchyCollapsed']);
        }
        final incoming = CollabRemotePointer.fromMessage(m);
        if (incoming != null) {
          final merged = CollabRemotePointer.mergeWithPrevious(
            incoming,
            _collabRemoteByUser[incoming.userId],
          );
          _collabRemoteByUser[incoming.userId] = merged;
          _collabPresenceRevision++;
          notifyListeners();
        }
        return;
      }
      if (ty == 'nexus_scene_crdt_merged') {
        if (m['fromUserId']?.toString() == uid) return;
        final sceneId = m['sceneId']?.toString() ?? '';
        final content = m['content'];
        if (content is Map<String, dynamic>) {
          _lastCollabSceneContent =
              Map<String, dynamic>.from(jsonDecode(jsonEncode(content)) as Map<dynamic, dynamic>);
          final rev = (m['revision'] as num?)?.toInt();
          unawaited(_applyRemoteSceneFromCollab(sceneId, content, rev));
        }
        return;
      }
      if (ty != 'nexus_scene_sync') return;
      if (m['fromUserId']?.toString() == uid) return;
      final sceneId = m['sceneId']?.toString() ?? '';
      final content = m['content'];
      if (content is! Map<String, dynamic>) return;
      final rev = (m['revision'] as num?)?.toInt();
      unawaited(_applyRemoteSceneFromCollab(sceneId, content, rev));
    } catch (e) {
      debugPrint('collab message: $e');
    }
  }

  Future<void> _applyRemoteSceneFromCollab(
    String sceneId,
    Map<String, dynamic> content,
    int? revision,
  ) async {
    if (_sceneProvider == null || _rootPath == null) return;
    final i = _scenes.indexWhere((s) => s.id == sceneId);
    if (i < 0) return;
    try {
      final merged = Scene.fromJson(content);
      if (revision != null) merged.cloudRevision = revision;
      _scenes[i] = merged;
      final filePath = path.join(_rootPath!, 'scenes', '$sceneId.json');
      await File(filePath).writeAsString(jsonEncode(merged.toJson()));
      if (_sceneProvider!.currentScene?.id == sceneId) {
        _sceneProvider!.setCurrentScene(merged);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('collab apply: $e');
    }
  }

  void ensureSceneCollaboration({
    required String projectId,
    required String sceneId,
    required String token,
    required String userId,
    required String apiBaseUrl,
  }) {
    if (_cloudReadOnly || _cloudSyncDio == null) {
      disposeSceneCollaboration();
      return;
    }
    if (projectId.isEmpty || sceneId.isEmpty) return;
    if (_collabProjectId == projectId &&
        _collabSceneId == sceneId &&
        _sceneCollabChannel != null) {
      return;
    }
    disposeSceneCollaboration();
    _collabProjectId = projectId;
    _collabSceneId = sceneId;
    _collabUserId = userId;
    _collabNeedsHierarchyBroadcast = true;
    try {
      final uri = _wsUriForCollab(apiBaseUrl, projectId, sceneId, token);
      final ch = WebSocketChannel.connect(uri);
      _sceneCollabChannel = ch;
      _sceneCollabSub = ch.stream.listen(
        _onCollabMessage,
        onError: (Object e) => debugPrint('collab stream: $e'),
        onDone: () => debugPrint('collab closed'),
      );
    } catch (e, st) {
      debugPrint('ensureSceneCollaboration: $e\n$st');
    }
  }
}
