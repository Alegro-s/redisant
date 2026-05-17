import 'package:flutter/foundation.dart';
import '../../data/models/lab_work.dart';
import '../../data/repositories/labs_repository.dart';

class LabsProvider with ChangeNotifier {
  final LabsRepository _repository = LabsRepository();
  List<LabWork> _labs = [];
  bool _isLoading = false;
  String? _error;

  List<LabWork> get labs => _labs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalLabs => _labs.length;
  int get passedLabs => _labs.where((l) => l.isPositive).length;

  Future<void> loadLabs() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _labs = await _repository.getLabs();
    } catch (e) {
      _error = 'Ошибка загрузки лабораторных (Moodle): $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
