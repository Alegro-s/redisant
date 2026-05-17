import 'package:flutter/foundation.dart';
import '../../data/models/exam.dart';
import '../../data/repositories/exams_repository.dart';

class ExamsProvider with ChangeNotifier {
  final ExamsRepository _repository = ExamsRepository();
  List<Exam> _upcomingExams = [];
  List<Exam> _completedExams = [];
  bool _isLoading = false;
  String? _error;

  List<Exam> get upcomingExams => _upcomingExams;
  List<Exam> get completedExams => _completedExams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadExams() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _upcomingExams = await _repository.getUpcomingExams();
      _completedExams = await _repository.getCompletedExams();
    } catch (e) {
      _error = 'Ошибка загрузки экзаменов: $e';
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