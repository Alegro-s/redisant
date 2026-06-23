import 'package:flutter/foundation.dart';

/// Режим UI движка: консоль (TIC) или полный проект (Unity-глубина).
enum EngineWorkspaceMode {
  project,
  console,
}

class EngineWorkspaceProvider extends ChangeNotifier {
  EngineWorkspaceMode _mode = EngineWorkspaceMode.project;
  int _consoleTab = 0;

  EngineWorkspaceMode get mode => _mode;
  int get consoleTab => _consoleTab;

  bool get isConsole => _mode == EngineWorkspaceMode.console;

  void setMode(EngineWorkspaceMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setConsoleTab(int index) {
    final i = index.clamp(0, 5);
    if (_consoleTab == i) return;
    _consoleTab = i;
    notifyListeners();
  }

  void toggleMode() {
    setMode(
      _mode == EngineWorkspaceMode.project
          ? EngineWorkspaceMode.console
          : EngineWorkspaceMode.project,
    );
  }
}
