import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'tsput_profile_secure'),
  );

  static Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  static Future<void> saveLoginData(String login, String password) async {
    try {
      await _storage.write(key: AppConstants.userLoginKey, value: login);
      await _storage.write(key: AppConstants.userPasswordKey, value: password);
    } catch (_) {}
    if (kIsWeb) {
      final p = await _prefs;
      await p.setString(AppConstants.userLoginKey, login);
      await p.setString(AppConstants.userPasswordKey, password);
    }
  }

  static Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: AppConstants.authTokenKey, value: token);
    } catch (_) {}
    if (kIsWeb) {
      final p = await _prefs;
      await p.setString(AppConstants.authTokenKey, token);
    }
  }

  static Future<void> saveBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: AppConstants.biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  static Future<String?> getLogin() async {
    try {
      final v = await _storage.read(key: AppConstants.userLoginKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    if (kIsWeb) {
      return (await _prefs).getString(AppConstants.userLoginKey);
    }
    return null;
  }

  static Future<String?> getPassword() async {
    try {
      final v = await _storage.read(key: AppConstants.userPasswordKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    if (kIsWeb) {
      return (await _prefs).getString(AppConstants.userPasswordKey);
    }
    return null;
  }

  static Future<String?> getAuthToken() async {
    try {
      final v = await _storage.read(key: AppConstants.authTokenKey);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    if (kIsWeb) {
      return (await _prefs).getString(AppConstants.authTokenKey);
    }
    return null;
  }

  static Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: AppConstants.biometricEnabledKey);
    return value == 'true';
  }

  static Future<void> clearAllData() async {
    await _clearKeys();
  }

  static Future<void> clearAuthData() async {
    try {
      await _storage.delete(key: AppConstants.authTokenKey);
    } catch (_) {}
    if (kIsWeb) {
      await (await _prefs).remove(AppConstants.authTokenKey);
    }
  }

  static Future<void> clearSavedCredentials() async {
    try {
      await _storage.delete(key: AppConstants.userLoginKey);
      await _storage.delete(key: AppConstants.userPasswordKey);
    } catch (_) {}
    if (kIsWeb) {
      final p = await _prefs;
      await p.remove(AppConstants.userLoginKey);
      await p.remove(AppConstants.userPasswordKey);
    }
  }

  static Future<bool> hasSavedCredentials() async {
    final login = await getLogin();
    final password = await getPassword();
    return login != null && password != null && login.isNotEmpty && password.isNotEmpty;
  }

  static Future<void> _clearKeys() async {
    for (final key in [
      AppConstants.userLoginKey,
      AppConstants.userPasswordKey,
      AppConstants.authTokenKey,
      AppConstants.biometricEnabledKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
    if (kIsWeb) {
      final p = await _prefs;
      for (final key in [
        AppConstants.userLoginKey,
        AppConstants.userPasswordKey,
        AppConstants.authTokenKey,
      ]) {
        await p.remove(key);
      }
    }
  }
}
