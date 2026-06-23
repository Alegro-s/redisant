import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/nexus_theme.dart';

enum AppTheme { purple, monochrome, midnight }

const List<Map<String, dynamic>> availableModules = [
  {
    'id': 'home',
    'title': 'Lynx Hub',
    'subtitle': 'Сводка, быстрые действия и обзор экосистемы.',
    'icon': Icons.home_outlined,
  },
  {
    'id': 'projects',
    'title': 'Проекты',
    'subtitle': 'Облачные и локальные проекты, артефакты сборок.',
    'icon': Icons.folder_outlined,
  },
  {
    'id': 'messenger',
    'title': 'Мессенджер',
    'subtitle': 'Личные и групповые чаты внутри Lynx.',
    'icon': Icons.chat_bubble_outline,
  },
  {
    'id': 'news',
    'title': 'Новости',
    'subtitle': 'Лента обновлений и анонсов (URL ленты задаётся в профиле).',
    'icon': Icons.newspaper_outlined,
  },
  {
    'id': 'store',
    'title': 'Lynx Cloud',
    'subtitle': 'Совместная работа, облачные сборки и публикация игр.',
    'icon': Icons.storefront_outlined,
  },
  {
    'id': 'arcade',
    'title': 'Аркада',
    'subtitle': 'Free-to-play каталог игр Lynx Cloud.',
    'icon': Icons.sports_esports_outlined,
  },
];

const Set<String> kReservedShellModuleIds = {
  'library',
  'github',
  'ai',
  'telemost',
};

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _modulesKey = 'enabled_modules';
  static const String _modulesOrderKey = 'modules_order';
  static const String _launchEditorSeparateKey = 'nexus_launch_editor_separate';
  static const String _editorExeKey = 'nexus_editor_executable';
  static const String _newsFeedUrlKey = 'nexus_news_feed_url';
  static const String _storeCatalogUrlKey = 'nexus_store_catalog_url';
  static const String _hubContentUrlKey = 'nexus_hub_content_url';
  static const String _liveOpsConfigUrlKey = 'nexus_live_ops_config_url';
  static const String _leaderboardApiUrlKey = 'nexus_leaderboard_api_url';
  static const String _marketplaceApiBaseKey = 'nexus_marketplace_api_base';

  AppTheme _currentTheme = AppTheme.purple;
  Set<String> _enabledModules = {'home', 'projects', 'messenger', 'news', 'store', 'arcade'};
  List<String> _modulesOrder = [];
  bool _launchEditorSeparate = false;
  String _nexusEditorExecutable = '';
  String _newsFeedUrl = '';
  String _storeCatalogUrl = '';
  String _hubContentUrl = '';
  String _liveOpsConfigUrl = '';
  String _leaderboardApiUrl = '';
  String _marketplaceApiBase = '';

  AppTheme get currentTheme => _currentTheme;
  Set<String> get enabledModules => _enabledModules;
  List<String> get modulesOrder => _modulesOrder;
  bool get launchEditorSeparate => _launchEditorSeparate;
  String get nexusEditorExecutablePath => _nexusEditorExecutable;
  String get newsFeedUrl => _newsFeedUrl;
  String get storeCatalogUrl => _storeCatalogUrl;
  String get hubContentUrl => _hubContentUrl;
  String get liveOpsConfigUrl => _liveOpsConfigUrl;
  String get leaderboardApiUrl => _leaderboardApiUrl;
  String get marketplaceApiBase => _marketplaceApiBase;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _currentTheme = AppTheme.values[themeIndex];

    final modulesString = prefs.getString(_modulesKey);
    if (modulesString != null && modulesString.isNotEmpty) {
      _enabledModules = modulesString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    }
    if (_enabledModules.isEmpty) {
      _enabledModules = {'home', 'projects', 'messenger', 'news', 'store', 'arcade'};
    }
    _enabledModules.removeWhere(kReservedShellModuleIds.contains);
    final validIds = availableModules.map((m) => m['id'] as String).toSet();
    _enabledModules = _enabledModules.where(validIds.contains).toSet();
    _enabledModules.add('home');

    final orderString = prefs.getString(_modulesOrderKey);
    if (orderString != null && orderString.isNotEmpty) {
      final seen = <String>{};
      _modulesOrder = [
        for (final id in orderString.split(','))
          if (id.isNotEmpty && seen.add(id)) id
      ];
    } else {
      _modulesOrder = availableModules.map((m) => m['id'] as String).toList();
    }
    _modulesOrder = _modulesOrder.where(validIds.contains).toList();
    for (final id in availableModules.map((m) => m['id'] as String)) {
      if (_enabledModules.contains(id) && !_modulesOrder.contains(id)) {
        _modulesOrder.add(id);
      }
    }

    _launchEditorSeparate = prefs.getBool(_launchEditorSeparateKey) ?? false;
    _nexusEditorExecutable = prefs.getString(_editorExeKey) ?? '';
    _newsFeedUrl = prefs.getString(_newsFeedUrlKey) ?? '';
    _storeCatalogUrl = prefs.getString(_storeCatalogUrlKey) ?? '';
    _hubContentUrl = prefs.getString(_hubContentUrlKey) ?? '';
    _liveOpsConfigUrl = prefs.getString(_liveOpsConfigUrlKey) ?? '';
    _leaderboardApiUrl = prefs.getString(_leaderboardApiUrlKey) ?? '';
    _marketplaceApiBase = prefs.getString(_marketplaceApiBaseKey) ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_currentTheme == theme) return;
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, theme.index);
    notifyListeners();
  }

  Future<void> toggleModule(String moduleId, bool enabled) async {
    if (!enabled) {
      if (moduleId == 'home') return;
      if (_enabledModules.length <= 1) return;
      if (!_enabledModules.contains(moduleId)) return;
    }
    if (enabled) {
      _enabledModules.add(moduleId);
    } else {
      _enabledModules.remove(moduleId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modulesKey, _enabledModules.join(','));
    _modulesOrder = _modulesOrder.where((id) => _enabledModules.contains(id)).toList();
    final allIds = availableModules.map((m) => m['id'] as String).toList();
    for (final id in allIds) {
      if (_enabledModules.contains(id) && !_modulesOrder.contains(id)) {
        _modulesOrder.add(id);
      }
    }
    await prefs.setString(_modulesOrderKey, _modulesOrder.join(','));
    notifyListeners();
  }

  Future<void> updateModulesOrder(List<String> newOrder) async {
    final seen = <String>{};
    _modulesOrder = [
      for (final id in newOrder.where(_enabledModules.contains))
        if (seen.add(id)) id
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modulesOrderKey, _modulesOrder.join(','));
    notifyListeners();
  }

  Future<void> applyEnabledModulesFromOnboarding(Set<String> moduleIds) async {
    final valid = availableModules.map((m) => m['id'] as String).toSet();
    final next = <String>{
      'home',
      for (final id in moduleIds)
        if (id.trim().isNotEmpty &&
            valid.contains(id.trim()) &&
            !kReservedShellModuleIds.contains(id.trim()))
          id.trim(),
    };
    _enabledModules = next;

    _modulesOrder = [
      for (final id in _modulesOrder)
        if (_enabledModules.contains(id)) id
    ];
    for (final id in availableModules.map((m) => m['id'] as String)) {
      if (_enabledModules.contains(id) && !_modulesOrder.contains(id)) {
        _modulesOrder.add(id);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modulesKey, _enabledModules.join(','));
    await prefs.setString(_modulesOrderKey, _modulesOrder.join(','));
    notifyListeners();
  }

  List<Map<String, dynamic>> getVisibleModulesInOrder() {
    final enabledSet = _enabledModules;
    final result = <Map<String, dynamic>>[];
    final addedIds = <String>{};

    Map<String, dynamic>? moduleById(String id) {
      for (final m in availableModules) {
        if (m['id'] == id) return Map<String, dynamic>.from(m);
      }
      return null;
    }

    for (final id in _modulesOrder) {
      if (!enabledSet.contains(id) || !addedIds.add(id)) continue;
      final m = moduleById(id);
      if (m != null) result.add(m);
    }
    for (final module in availableModules) {
      final id = module['id']?.toString() ?? '';
      if (id.isEmpty || !enabledSet.contains(id) || !addedIds.add(id)) continue;
      result.add(Map<String, dynamic>.from(module));
    }
    return result;
  }

  Future<void> setLaunchEditorSeparate(bool v) async {
    _launchEditorSeparate = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_launchEditorSeparateKey, v);
    notifyListeners();
  }

  Future<void> setNexusEditorExecutablePath(String path) async {
    _nexusEditorExecutable = path.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_editorExeKey, _nexusEditorExecutable);
    notifyListeners();
  }

  Future<void> setNewsFeedUrl(String url) async {
    _newsFeedUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_newsFeedUrlKey, _newsFeedUrl);
    notifyListeners();
  }

  Future<void> setStoreCatalogUrl(String url) async {
    _storeCatalogUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeCatalogUrlKey, _storeCatalogUrl);
    notifyListeners();
  }

  Future<void> setHubContentUrl(String url) async {
    _hubContentUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hubContentUrlKey, _hubContentUrl);
    notifyListeners();
  }

  Future<void> setLiveOpsConfigUrl(String url) async {
    _liveOpsConfigUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_liveOpsConfigUrlKey, _liveOpsConfigUrl);
    notifyListeners();
  }

  Future<void> setLeaderboardApiUrl(String url) async {
    _leaderboardApiUrl = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_leaderboardApiUrlKey, _leaderboardApiUrl);
    notifyListeners();
  }

  Future<void> setMarketplaceApiBase(String url) async {
    _marketplaceApiBase = url.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_marketplaceApiBaseKey, _marketplaceApiBase);
    notifyListeners();
  }

  ThemeData getThemeData() {
    switch (_currentTheme) {
      case AppTheme.purple:
        return NexusTheme.darkPurple();
      case AppTheme.monochrome:
        return NexusTheme.lightClean();
      case AppTheme.midnight:
        return NexusTheme.darkSlate();
    }
  }
}