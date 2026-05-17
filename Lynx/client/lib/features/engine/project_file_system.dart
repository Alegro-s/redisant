import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class ProjectFileSystem {
  final String rootPath;
  ProjectFileSystem(this.rootPath);
  String get assetsPath => path.join(rootPath, 'assets');
  String get spritesPath => path.join(assetsPath, 'sprites');
  String get scriptsPath => path.join(assetsPath, 'scripts');
  String get soundsPath => path.join(assetsPath, 'sounds');
  String get scenesPath => path.join(rootPath, 'scenes');
  String get projectFilePath => path.join(rootPath, 'project.nexus');
  Future<List<FileSystemEntity>> listSprites() async {
    final dir = Directory(spritesPath);
    if (!await dir.exists()) return [];
    return dir.list().toList();
  }
  Future<List<FileSystemEntity>> listScripts() async {
    final dir = Directory(scriptsPath);
    if (!await dir.exists()) return [];
    return dir.list().toList();
  }
  Future<List<FileSystemEntity>> listSounds() async {
    final dir = Directory(soundsPath);
    if (!await dir.exists()) return [];
    return dir.list().toList();
  }
  Future<Map<String, dynamic>> loadProjectMetadata() async {
    final file = File(projectFilePath);
    if (!await file.exists()) return {};
    final content = await file.readAsString();
    return jsonDecode(content);
  }
  Future<void> saveScene(String name, String json) async {
    final file = File(path.join(scenesPath, name));
    await file.writeAsString(json);
  }
  Future<String?> loadScene(String name) async {
    final file = File(path.join(scenesPath, name));
    if (!await file.exists()) return null;
    return await file.readAsString();
  }
}