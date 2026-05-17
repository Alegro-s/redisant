import 'package:flutter/foundation.dart';
import '../../data/models/student.dart';
import '../../data/repositories/student_repository.dart';

class StudentProvider with ChangeNotifier {
  final StudentRepository _repository = StudentRepository();
  Student? _student;
  bool _isLoading = false;
  String? _error;

  Student? get student => _student;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadStudentData() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _student = await _repository.getStudentData();
    } catch (e) {
      _error = 'Ошибка загрузки данных студента: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateStudentInfo(Map<String, dynamic> updates) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateStudentInfo(updates);
      await loadStudentData();
    } catch (e) {
      _error = 'Ошибка обновления данных: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
  void clearStudentData() {
    _student = null;
    notifyListeners();
  }
}