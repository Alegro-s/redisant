import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';
import 'api_exception.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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
    return _getJson('$_base${AppConstants.studentEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchSchedule(String token) async {
    return _getList('$_base${AppConstants.scheduleEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchGrades(String token) async {
    return _getList('$_base${AppConstants.gradesEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchExams(String token) async {
    return _getList('$_base${AppConstants.examsEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchPortfolio(String token) async {
    return _getList('$_base${AppConstants.portfolioEndpoint}', token: token);
  }

  Future<List<dynamic>> fetchMoodleLabs(String token) async {
    return _getList('$_base${AppConstants.moodleLabsEndpoint}', token: token);
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
