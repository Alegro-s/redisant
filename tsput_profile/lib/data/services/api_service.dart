import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import '../../core/demo_student.dart';
import '../../core/integration_runtime.dart';
import 'api_exception.dart';
import 'supabase_rest.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final SupabaseRest _supabase = SupabaseRest();

  static const Duration _timeout = Duration(seconds: 12);

  String get _base => AppConstants.integrationBaseUrl.replaceAll(RegExp(r'/$'), '');

  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final url = '$_base${AppConstants.loginEndpoint}';
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'login': login, 'password': password}),
          )
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {}
      return {'success': false, 'error': 'Ошибка входа (${response.statusCode})'};
    } catch (e) {
      return {
        'success': false,
        'error': 'Нет подключения к серверу: $e',
      };
    }
  }

  Future<Map<String, dynamic>> fetchStudentData(String token) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      return DemoStudent.toJson();
    }
    return _getJson('$_base${AppConstants.studentEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchSchedule(String token) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      final rows = await _supabase.fetchTable('tspu_schedule', order: 'start_time.asc');
      return rows.map(SupabaseRest.mapScheduleRow).toList();
    }
    return _getList('$_base${AppConstants.scheduleEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchGrades(String token) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      final rows = await _supabase.fetchTable('tspu_grades', order: 'date.desc');
      return rows.map(SupabaseRest.mapGradeRow).toList();
    }
    return _getList('$_base${AppConstants.gradesEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchExams(String token) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      final rows = await _supabase.fetchTable('tspu_exams');
      return rows.map(SupabaseRest.mapExamRow).toList();
    }
    return _getList('$_base${AppConstants.examsEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchPortfolio(String token) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      final rows = await _supabase.fetchTable('tspu_portfolio', order: 'item_date.desc');
      return rows.map(SupabaseRest.mapPortfolioRow).toList();
    }
    return _getList('$_base${AppConstants.portfolioEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchMoodleLabs(String token) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      return _supabase.fetchLabsMerged();
    }
    return _getList('$_base${AppConstants.moodleLabsEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchLabComments(String token, String labId) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      final rows = await _supabase.fetchLabComments(labId);
      return rows
          .map(
            (row) => {
              'id': row['id'],
              'text': row['text'],
              'timestamp': row['created_at'],
              'authorName': row['author_name'],
            },
          )
          .toList();
    }
    final url = '$_base${AppConstants.moodleLabsEndpoint}/$labId/comments';
    return _getList(url, token: token);
  }

  Future<Map<String, dynamic>> addLabComment(String token, String labId, String text) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      return _supabase.addLabComment(labId, text);
    }
    final url = '$_base${AppConstants.moodleLabsEndpoint}/$labId/comments';
    if (token.isEmpty) {
      throw ApiException('Нет токена авторизации');
    }
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'text': text}),
        )
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException('Ошибка комментария (${response.statusCode})');
  }

  Future<Map<String, dynamic>> submitLab(
    String token,
    String labId, {
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    if (IntegrationRuntime.useSupabaseDirect) {
      return _supabase.submitLabDirect(labId, fileName);
    }
    if (token.isEmpty) {
      throw ApiException('Нет токена авторизации');
    }
    final url = '$_base${AppConstants.moodleLabsEndpoint}/$labId/submit';
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    if (filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('file', filePath, filename: fileName));
    } else if (fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    } else {
      throw ApiException('Файл не выбран');
    }
    final streamed = await request.send().timeout(_timeout);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    throw ApiException('Ошибка отправки (${streamed.statusCode})');
  }

  Future<Map<String, dynamic>> fetchAppRelease() async {
    if (IntegrationRuntime.useSupabaseDirect) {
      return _supabase.fetchAppRelease();
    }
    final url = '$_base/api/app/release';
    final response = await _client.get(Uri.parse(url)).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException('Release ${response.statusCode}');
  }

  Future<List<dynamic>> adminFetchSchedule(String adminToken) async {
    final url = '$_base${AppConstants.adminScheduleEndpoint}';
    final response = await _client
        .get(Uri.parse(url), headers: {'X-Admin-Token': adminToken})
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException('Admin schedule GET ${response.statusCode}');
  }

  Future<List<dynamic>> adminSaveSchedule(String adminToken, List<Map<String, dynamic>> items) async {
    final url = '$_base${AppConstants.adminScheduleEndpoint}';
    final response = await _client
        .put(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-Admin-Token': adminToken,
          },
          body: jsonEncode(items),
        )
        .timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException('Admin schedule PUT ${response.statusCode}');
  }

  Future<void> syncWithBackend() async {
    final url = '$_base${AppConstants.syncEndpoint}';
    await _client
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({}),
        )
        .timeout(_timeout);
  }

  Future<Map<String, dynamic>> _getJson(String url, {required String token}) async {
    if (token.isEmpty) {
      throw ApiException('Нет токена авторизации');
    }
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401) {
        throw ApiException('Сессия недействительна (401)');
      }
      throw ApiException('Ошибка сервера (${response.statusCode})');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Сеть или сервер недоступны: $e');
    }
  }

  Future<List<dynamic>> _getList(String url, {required String token}) async {
    if (token.isEmpty) {
      throw ApiException('Нет токена авторизации');
    }
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List<dynamic>) return decoded;
        throw ApiException('Неверный формат ответа');
      }
      if (response.statusCode == 401) {
        throw ApiException('Сессия недействительна (401)');
      }
      throw ApiException('Ошибка сервера (${response.statusCode})');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Сеть или сервер недоступны: $e');
    }
  }
}
