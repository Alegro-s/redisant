import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/register_outcome.dart';
import '../models/user.dart';

String? _apiErrorRaw(dynamic data) {
  if (data is Map && data['error'] != null) {
    return data['error'].toString();
  }
  return null;
}

String _dioConnectionFallback(DioException e) {
  final base = e.requestOptions.baseUrl;
  final raw = e.message?.trim();
  final tech = (raw != null && raw.isNotEmpty) ? ' Тех.детали: $raw' : '';
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return 'Нет ответа от $base (сеть или сервер недоступен). Проверьте URL в профиле '
          '(должен быть API, например http://IP:8080, не главная страница сайта), фаервол и VPN. '
          'Обновите приложение: для HTTP к IP на Android включён доступ без TLS.$tech';
    case DioExceptionType.badCertificate:
      return 'Ошибка сертификата при подключении к $base. Проверьте HTTPS/дату на устройстве.$tech';
    default:
      return 'Нет связи с сервером. Проверьте URL API в профиле и сеть. Сейчас: $base.$tech';
  }
}

String _friendlyAuthError(dynamic responseData, {required String fallback}) {
  final raw = _apiErrorRaw(responseData);
  if (raw == null) return fallback;
  if (raw == 'Invalid login or password') {
    return 'Неверный email/ник или пароль. Пустая база? Сначала зарегистрируйтесь во вкладке «Нет аккаунта».';
  }
  if (raw == 'Email or nickname already taken') {
    return 'Этот email или ник уже заняты.';
  }
  if (raw.startsWith('Admin self-registration is disabled')) {
    return 'Регистрация администраторов на сервере выключена (ADMIN_OPEN_REGISTRATION).';
  }
  return raw;
}

String? _gateEmailVerify(dynamic data) {
  if (data is Map && data['error_code'] == 'email_not_verified') {
    final em = data['email']?.toString() ?? '';
    return 'EMAIL_VERIFY_REQUIRED|$em';
  }
  return null;
}

String? _tokenFromResponse(dynamic data) {
  if (data is! Map) return null;
  final t = data['token'];
  if (t == null) return null;
  final s = t.toString();
  return s.isEmpty ? null : s;
}

String _normalizeApiBase(String value) {
  var trimmed = value.trim();
  if (trimmed.isEmpty) return '${AuthProvider.defaultApiBase}/';
  if (!trimmed.contains('://')) {
    trimmed = 'https://$trimmed';
  }
  return trimmed.endsWith('/') ? trimmed : '$trimmed/';
}

class AuthProvider extends ChangeNotifier {
  static const String _prefsApiBase = 'api_base_url';
  static const String _webTokenKey = 'auth_token_web_backup';
  static const String _webIngestKey = 'ingest_api_key_web_backup';
  static const String defaultApiBase = 'https://api.lynx-cloud.ru';

  static const String clientRealm = 'nexus';

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  User? _user;
  String? _ingestApiKey;
  bool _bootstrapped = false;

  String? get token => _token;
  User? get user => _user;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get bootstrapped => _bootstrapped;
  String? get ingestApiKey => _ingestApiKey;
  String get dioBaseUrl => _dio.options.baseUrl;
  Dio get http => _dio;

  AuthProvider()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _normalizeApiBase(defaultApiBase),
            connectTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 45),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Client-Realm'] = clientRealm;
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
      ),
    );
    _init();
  }

  Future<void> _persistToken(String token) async {
    _token = token;
    await _storage.write(key: 'token', value: token);
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString(_webTokenKey, token);
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsApiBase);
      if (saved != null && saved.trim().isNotEmpty) {
        var base = saved.trim().replaceAll(RegExp(r'/$'), '');
        final legacyRoots = {
          'https://metrika-waypoint.ru',
          'http://metrika-waypoint.ru',
          'https://metrika-waypoint.ru/api',
          'http://metrika-waypoint.ru/api',
          'https://lynx-cloud.ru',
          'http://lynx-cloud.ru',
          'https://www.lynx-cloud.ru',
          'http://www.lynx-cloud.ru',
        };
        if (legacyRoots.contains(base)) {
          base = defaultApiBase;
          await prefs.setString(_prefsApiBase, base);
        }
        _dio.options.baseUrl = _normalizeApiBase(base);
      }

      String? tok = await _storage.read(key: 'token');
      if (kIsWeb && (tok == null || tok.isEmpty)) {
        tok = prefs.getString(_webTokenKey);
        if (tok != null && tok.isNotEmpty) {
          await _storage.write(key: 'token', value: tok);
        }
      }
      _token = (tok != null && tok.isNotEmpty) ? tok : null;

      String? ik = await _storage.read(key: 'ingest_api_key');
      if (kIsWeb && (ik == null || ik.isEmpty)) {
        ik = prefs.getString(_webIngestKey);
        if (ik != null && ik.isNotEmpty) {
          await _storage.write(key: 'ingest_api_key', value: ik);
        }
      }
      _ingestApiKey = (ik != null && ik.isNotEmpty) ? ik : null;

      if (isAuthenticated) {
        await fetchProfile();
      }
    } catch (e, st) {
      debugPrint('AuthProvider._init: $e\n$st');
      _token = null;
      _user = null;
    } finally {
      _bootstrapped = true;
      notifyListeners();
    }
  }

  Future<void> setApiBaseUrl(String url) async {
    var u = url.trim().replaceAll(RegExp(r'/$'), '');
    if (u.isEmpty) u = defaultApiBase.replaceAll(RegExp(r'/$'), '');
    _dio.options.baseUrl = _normalizeApiBase(u);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsApiBase, u);
    notifyListeners();
  }

  Future<void> _persistIngestKey(String? key) async {
    _ingestApiKey = key;
    if (key == null || key.isEmpty) {
      await _storage.delete(key: 'ingest_api_key');
      if (kIsWeb) {
        final p = await SharedPreferences.getInstance();
        await p.remove(_webIngestKey);
      }
    } else {
      await _storage.write(key: 'ingest_api_key', value: key);
      if (kIsWeb) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_webIngestKey, key);
      }
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchVkBindCode() async {
    if (!isAuthenticated) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>('profile/vk-code');
      return response.data;
    } catch (e) {
      debugPrint('vk-code: $e');
      return null;
    }
  }

  Future<RegisterOutcome> register({
    required String email,
    String? phone,
    required String fullName,
    required String nickname,
    required String password,
    Map<String, dynamic>? settings,
  }) async {
    try {
      final response = await _dio.post('register', data: {
        'email': email.trim(),
        'phone': phone,
        'full_name': fullName,
        'nickname': nickname,
        'password': password,
        'settings': settings ?? {},
      });
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['status'] == 'pending_verification') {
          final em = data['email']?.toString().trim() ?? email.trim();
          return RegisterOutcome.pending(em);
        }
        final t = _tokenFromResponse(data);
        if (t == null) return RegisterOutcome.fail('Нет токена в ответе сервера');
        await _persistToken(t);
        if (data is Map) {
          final ik = data['ingest_api_key']?.toString();
          if (ik != null && ik.isNotEmpty) {
            await _persistIngestKey(ik);
          }
        }
        await fetchProfile();
        return RegisterOutcome.success();
      } else {
        final err = response.data is Map ? (response.data as Map)['error'] : null;
        return RegisterOutcome.fail(err?.toString() ?? 'Registration failed');
      }
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['error'] != null) return RegisterOutcome.fail(d['error'].toString());
      return RegisterOutcome.fail(_dioConnectionFallback(e));
    }
  }

  Future<String?> verifyRegistrationEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/register/verify',
        data: {
          'email': email.trim().toLowerCase(),
          'code': code.replaceAll(RegExp(r'\s'), ''),
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final t = _tokenFromResponse(data);
        if (t == null) return 'Нет токена в ответе сервера';
        await _persistToken(t);
        final ik = data['ingest_api_key']?.toString();
        if (ik != null && ik.isNotEmpty) await _persistIngestKey(ik);
        await fetchProfile();
        return null;
      }
      final err = response.data?['error'];
      return err?.toString() ?? 'Ошибка подтверждения';
    } on DioException catch (e) {
      return _friendlyAuthError(e.response?.data, fallback: _dioConnectionFallback(e));
    }
  }

  Future<String?> resendRegistrationEmail(String email) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/register/resend',
        data: {'email': email.trim().toLowerCase()},
      );
      if (response.statusCode == 200) return null;
      final err = response.data?['error'];
      return err?.toString() ?? 'Не удалось отправить письмо';
    } on DioException catch (e) {
      return _friendlyAuthError(e.response?.data, fallback: _dioConnectionFallback(e));
    }
  }

  Future<String?> login(String login, String password) async {
    try {
      final response = await _dio.post('login', data: {
        'login': login,
        'password': password,
      });
      if (response.statusCode == 200) {
        final data = response.data;
        final t = _tokenFromResponse(data);
        if (t == null) return 'Нет токена в ответе сервера';
        await _persistToken(t);
        if (data is Map) {
          final ik = data['ingest_api_key']?.toString();
          if (ik != null && ik.isNotEmpty) {
            await _persistIngestKey(ik);
          }
        }
        await fetchProfile();
        return null;
      } else {
        final err = response.data is Map ? (response.data as Map)['error'] : null;
        return err?.toString() ?? 'Login failed';
      }
    } on DioException catch (e) {
      final gate = _gateEmailVerify(e.response?.data);
      if (e.response?.statusCode == 403 && gate != null) return gate;
      final fallback =
          e.response != null ? 'Нет связи с сервером. Проверьте URL API в профиле и сеть.' : _dioConnectionFallback(e);
      return _friendlyAuthError(e.response?.data, fallback: fallback);
    }
  }

  Future<(List<String>, String?)> loginOtpPreview(String login, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/login/challenge-preview',
        data: {'login': login.trim(), 'password': password},
      );
      if (response.statusCode == 200 && response.data != null) {
        final ch = response.data!['channels'];
        if (ch is List) {
          return (ch.map((e) => e.toString()).toList(), null);
        }
      }
      return (<String>[], 'Сервер не вернул каналы доставки');
    } on DioException catch (e) {
      final gate = _gateEmailVerify(e.response?.data);
      if (e.response?.statusCode == 403 && gate != null) {
        return (<String>[], gate);
      }
      return (
        <String>[],
        _friendlyAuthError(e.response?.data, fallback: 'Неверный логин или пароль'),
      );
    }
  }

  Future<(Map<String, dynamic>?, String?)> loginOtpRequestCode({
    required String login,
    required String password,
    required String channel,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/login/challenge',
        data: {
          'login': login.trim(),
          'password': password,
          'channel': channel,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return (Map<String, dynamic>.from(response.data!), null);
      }
      return (null, 'Нет ответа от сервера');
    } on DioException catch (e) {
      final gate = _gateEmailVerify(e.response?.data);
      if (e.response?.statusCode == 403 && gate != null) {
        return (null, gate);
      }
      return (null, _friendlyAuthError(e.response?.data, fallback: 'Не удалось отправить код'));
    }
  }

  Future<(String?, String?)> loginOtpFetchNexusCode({
    required String challengeId,
    required String sessionToken,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'auth/challenge/nexus-code',
        queryParameters: {'challenge_id': challengeId, 'session_token': sessionToken},
      );
      if (response.statusCode == 200 && response.data != null) {
        final c = response.data!['code']?.toString();
        if (c != null && c.length == 6) return (c, null);
      }
      return (null, 'Код недоступен');
    } on DioException catch (e) {
      return (null, _apiErrorRaw(e.response?.data) ?? 'Ошибка запроса');
    }
  }

  Future<String?> loginOtpVerify({
    required String challengeId,
    required String sessionToken,
    required String code,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/login/verify',
        data: {
          'challenge_id': challengeId,
          'session_token': sessionToken,
          'code': code.replaceAll(RegExp(r'\s'), ''),
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final t = _tokenFromResponse(data);
        if (t == null) return 'Нет токена в ответе сервера';
        await _persistToken(t);
        final ik = data['ingest_api_key']?.toString();
        if (ik != null && ik.isNotEmpty) {
          await _persistIngestKey(ik);
        }
        await fetchProfile();
        return null;
      }
      final err = response.data?['error'];
      return err?.toString() ?? 'Ошибка проверки';
    } on DioException catch (e) {
      return _friendlyAuthError(e.response?.data, fallback: 'Нет связи с сервером');
    }
  }

  Future<void> fetchProfile() async {
    if (!isAuthenticated) return;
    try {
      final response = await _dio.get('profile');
      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        if (raw is! Map) {
          throw FormatException('profile is ${raw.runtimeType}');
        }
        final map = Map<String, dynamic>.from(
          raw.map((k, v) => MapEntry(k.toString(), v)),
        );
        _user = User.fromJson(map);
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('fetchProfile: $e\n$st');
      await logout();
    }
  }

  Future<String?> linkRealm({required String realm, required String password}) async {
    if (!isAuthenticated) return 'Сначала войдите';
    final r = realm.trim().toLowerCase();
    if (r != 'nexus' && r != 'metric') {
      return 'Некорректная область';
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        'auth/realms/link',
        data: {'realm': r, 'password': password},
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data!['realms'];
        if (list is List) {
          _user = _user?.copyWith(
            realms: list.map((e) => e.toString()).toList(),
          );
          notifyListeners();
        } else {
          await fetchProfile();
        }
        return null;
      }
      final err = response.data?['error'];
      return err?.toString() ?? 'Не удалось подключить';
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['error'] != null) return d['error'].toString();
      return 'Ошибка сети';
    }
  }

  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    Map<String, dynamic>? settings,
  }) async {
    if (!isAuthenticated) return;
    try {
      final response = await _dio.put(
        'profile',
        data: {
          'full_name': ?fullName,
          'avatar_url': ?avatarUrl,
          'settings': ?settings,
        },
      );
      if (response.statusCode == 200) {
        _user = _user?.copyWith(
          fullName: fullName,
          avatarUrl: avatarUrl,
          settings: settings,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to update profile: $e');
    }
  }

  Future<String?> uploadAvatarBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (!isAuthenticated) return null;
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        'profile/avatar',
        data: formData,
      );

      if (response.statusCode == 200 && response.data != null) {
        final avatarUrl = response.data!['avatar_url']?.toString();
        await fetchProfile(); // чтобы UI сразу показал новую аватарку
        return avatarUrl;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('uploadAvatarBytes: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      debugPrint('uploadAvatarBytes: $e');
      return null;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _ingestApiKey = null;
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'ingest_api_key');
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.remove(_webTokenKey);
      await p.remove(_webIngestKey);
    }
    notifyListeners();
  }
}