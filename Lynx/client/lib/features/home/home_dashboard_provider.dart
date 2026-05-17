import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> kHomeBlockIds = [
  'profile',
  'activity',
  'projects',
];

class HomeDashboardProvider extends ChangeNotifier {
  static const _kOrder = 'home_block_order_v1';
  static const _kEditor = 'home_editor_mode_v1';

  List<String> _order = List<String>.from(kHomeBlockIds);
  bool _editorMode = false;
  bool _loaded = false;

  List<String> get blockOrder => List.unmodifiable(_order);
  bool get editorMode => _editorMode;
  bool get loaded => _loaded;

  HomeDashboardProvider() {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kOrder);
    if (raw != null && raw.isNotEmpty) {
      final parsed = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final seen = <String>{};
      _order = [
        for (final id in parsed)
          if (kHomeBlockIds.contains(id) && seen.add(id)) id,
      ];
      for (final id in kHomeBlockIds) {
        if (!_order.contains(id)) _order.add(id);
      }
    } else {
      _order = List<String>.from(kHomeBlockIds);
    }
    _editorMode = p.getBool(_kEditor) ?? false;
    _loaded = true;
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> setEditorMode(bool value) async {
    _editorMode = value;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEditor, value);
  }

  Future<void> reorderBlocks(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _order.removeAt(oldIndex);
    _order.insert(newIndex, item);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOrder, _order.join(','));
  }

  Future<void> resetBlockOrder() async {
    _order = List<String>.from(kHomeBlockIds);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kOrder);
  }
}
