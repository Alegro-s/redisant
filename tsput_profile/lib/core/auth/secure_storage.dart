import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants.dart';

class SecureStorage {
  static final _storage = FlutterSecureStorage();

  static Future<void> saveLoginData(String login, String password) async {
    await _storage.write(key: AppConstants.userLoginKey, value: login);
    await _storage.write(key: AppConstants.userPasswordKey, value: password);
  }

  static Future<void> saveAuthToken(String token) async {
    await _storage.write(key: AppConstants.authTokenKey, value: token);
  }

  static Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  static Future<String?> getLogin() async {
    return await _storage.read(key: AppConstants.userLoginKey);
  }

  static Future<String?> getPassword() async {
    return await _storage.read(key: AppConstants.userPasswordKey);
  }

  static Future<String?> getAuthToken() async {
    return await _storage.read(key: AppConstants.authTokenKey);
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: AppConstants.biometricEnabledKey);
    return value == 'true';
  }

  static Future<void> clearAllData() async {
    await _storage.delete(key: AppConstants.userLoginKey);
    await _storage.delete(key: AppConstants.userPasswordKey);
    await _storage.delete(key: AppConstants.authTokenKey);
    await _storage.delete(key: AppConstants.biometricEnabledKey);
  }

  static Future<void> clearAuthData() async {
    await _storage.delete(key: AppConstants.authTokenKey);
  }

  static Future<void> clearSavedCredentials() async {
    await _storage.delete(key: AppConstants.userLoginKey);
    await _storage.delete(key: AppConstants.userPasswordKey);
  }

  static Future<bool> hasSavedCredentials() async {
    final login = await getLogin();
    final password = await getPassword();
    return login != null && password != null && login.isNotEmpty && password.isNotEmpty;
  }
}