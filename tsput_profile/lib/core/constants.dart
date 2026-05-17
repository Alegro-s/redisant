import 'package:flutter/material.dart';

import 'integration_runtime.dart';

class AppConstants {
  static const String appName = 'ТГПУ профиль';

  static String get integrationBaseUrl => IntegrationRuntime.baseUrl;

  static const String portalRegisterUrl = 'https://tsput.ru';
  static const String portalStudyUrl = 'https://study.tsput.ru';
  static const String loyaltyTelegramBotUrl = 'https://t.me/tsputloyalty_bot';

  static const String authTokenKey = 'auth_token';
  static const String userLoginKey = 'user_login';
  static const String userPasswordKey = 'user_password';
  static const String biometricEnabledKey = 'biometric_enabled';
  static const String loyaltyLinkedEmailPrefKey = 'loyalty_linked_email';
  static const String loginEndpoint = '/api/auth/login';
  static const String syncEndpoint = '/api/sync';
  static const String studentEndpoint = '/api/student';
  static const String scheduleEndpoint = '/api/schedule';
  static const String gradesEndpoint = '/api/grades';
  static const String examsEndpoint = '/api/exams';
  static const String portfolioEndpoint = '/api/portfolio';
  static const String moodleLabsEndpoint = '/api/moodle/labs';
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF5F5F4);
  static const Color blockBlack = Color(0xFF121212);
  static const Color blockBlackElevated = Color(0xFF1E1E1E);
  static const Color onBlock = Color(0xFFF5F5F4);
  static const Color onBlockSecondary = Color(0xFFB0B0A8);
  static const Color terracotta = Color(0xFFC45D45);
  static const Color terracottaDark = Color(0xFFA34A35);
  static const Color terracottaMuted = Color(0xFFE8D5CF);
  static const Color borderSubtle = Color(0xFFE8E8E6);
  static const Color sheetHandle = Color(0xFFE0E0DE);

  static const double cardRadius = 16.0;
  static const double sheetTopRadius = 20.0;
  static const double buttonHeight = 52.0;

  static const Color backgroundColor = surfaceWhite;
  static const Color primaryColor = blockBlack;
  static const Color primaryDark = blockBlackElevated;
  static const Color secondaryColor = Color(0xFF6B6B66);
  static const Color accentYellow = terracotta;
  static const Color accentOrange = terracottaDark;
  static const Color cardWhite = surfaceWhite;

  @Deprecated('Use terracotta')
  static const Color accentColor = terracotta;
}
