import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/project.dart';
import '../../auth/providers/auth_provider.dart';

class ProjectProvider extends ChangeNotifier {
  final AuthProvider _auth;
  List<Project> _projects = [];
  Project? _currentProject;

  List<Project> get projects => _projects;
  Project? get currentProject => _currentProject;

  ProjectProvider(this._auth) {
    _auth.addListener(_sync);
  }

  void _sync() {
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_sync);
    super.dispose();
  }

  Future<String?> createProject(String name, String? description, String visibility) async {
    try {
      final response = await _auth.http.post('/projects', data: {
        'name': name,
        'description': description,
        'visibility': visibility,
      });
      if (response.statusCode == 200) {
        final project = Project.fromJson(response.data as Map<String, dynamic>);
        _projects.add(project);
        notifyListeners();
        return null;
      } else {
        return response.data['error'] ?? 'Failed to create project';
      }
    } on DioException catch (e) {
      return e.response?.data['error'] ?? 'Network error';
    }
  }

  Future<String?> loadProjects() async {
    try {
      final response = await _auth.http.get('/projects');
      if (response.statusCode == 200) {
        final raw = response.data;
        if (raw is! List) {
          debugPrint('ProjectProvider.loadProjects: expected JSON array, got ${raw.runtimeType}');
          _projects = [];
          notifyListeners();
          if (raw is Map && raw['error'] != null) {
            return raw['error'].toString();
          }
          return 'Ответ сервера не похож на список проектов';
        }
        _projects = raw.map((json) => Project.fromJson(json as Map<String, dynamic>)).toList();
        notifyListeners();
        return null;
      }
      final err = response.data;
      if (err is Map && err['error'] != null) return err['error'].toString();
      return 'Не удалось загрузить проекты';
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['error'] != null) return d['error'].toString();
      if (d is String && d.isNotEmpty) return d;
      return e.message ?? 'Ошибка сети';
    }
  }

  Future<Map<String, dynamic>?> previewShareSlug(String slug) async {
    try {
      final r = await _auth.http.get('/projects/preview/${Uri.encodeComponent(slug)}');
      if (r.statusCode == 200) return r.data as Map<String, dynamic>?;
    } catch (_) {}
    return null;
  }

  Future<String?> joinProjectBySlug(String slug) async {
    try {
      final r = await _auth.http.post('/projects/join-link', data: {'slug': slug.trim()});
      if (r.statusCode == 200) {
        await loadProjects();
        return null;
      }
      return r.data['error'] ?? 'Не удалось вступить';
    } on DioException catch (e) {
      return e.response?.data['error'] ?? 'Network error';
    }
  }

  Future<String?> enableShare(String projectId) async {
    try {
      final r = await _auth.http.post('/projects/$projectId/share');
      if (r.statusCode == 200) {
        await loadProjects();
        return null;
      }
      return r.data['error'] ?? 'Ошибка';
    } on DioException catch (e) {
      return e.response?.data['error'] ?? 'Network error';
    }
  }

  void setCurrentProject(Project project) {
    _currentProject = project;
    notifyListeners();
  }

  Project? findById(String id) {
    try {
      return _projects.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
