import '../../data/services/api_service.dart';
import 'secure_storage.dart';

class AuthService {
  static final ApiService _apiService = ApiService();

  static Future<Map<String, dynamic>> login(
    String login,
    String password, {
    bool rememberCredentials = true,
  }) async {
    final response = await _apiService.login(login: login, password: password);
    if (response['success'] == true) {
      final token = response['token'] as String;
      if (rememberCredentials) {
        await SecureStorage.saveLoginData(login, password);
      } else {
        await SecureStorage.clearSavedCredentials();
      }
      await SecureStorage.saveAuthToken(token);
      return response;
    }
    return response;
  }

  static Future<bool> validateToken(String token) async {
    if (token.isEmpty) return false;
    try {
      final studentData = await _apiService.fetchStudentData(token);
      return studentData.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() async {
    await SecureStorage.clearAuthData();
  }

  static Future<bool> isAuthenticated() async {
    final token = await SecureStorage.getAuthToken();
    if (token == null) return false;
    return validateToken(token);
  }

  static Future<Map<String, String>?> getSavedCredentials() async {
    final login = await SecureStorage.getLogin();
    final password = await SecureStorage.getPassword();

    if (login != null && password != null) {
      return {'login': login, 'password': password};
    }

    return null;
  }

  static Future<bool> autoLogin() async {
    final credentials = await getSavedCredentials();
    if (credentials == null) return false;

    final result = await login(
      credentials['login']!,
      credentials['password']!,
      rememberCredentials: true,
    );
    return result['success'] == true;
  }
}