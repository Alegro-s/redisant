import 'package:flutter/foundation.dart';
import '../../data/models/grade.dart';
import '../../data/repositories/grades_repository.dart';

class GradesProvider with ChangeNotifier {
  final GradesRepository _repository = GradesRepository();
  List<Grade> _grades = [];
  double _averageGrade = 0.0;
  bool _isLoading = false;
  String? _error;

  List<Grade> get grades => _grades;
  double get averageGrade => _averageGrade;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGrades() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _grades = await _repository.getGrades();
      _averageGrade = await _repository.getAverageGrade();
    } catch (e) {
      _error = 'Ошибка загрузки оценок: $e';
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