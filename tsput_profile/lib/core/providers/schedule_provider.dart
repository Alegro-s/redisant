import 'package:flutter/foundation.dart';
import '../../data/models/schedule.dart';
import '../../data/repositories/schedule_repository.dart';

class ScheduleProvider with ChangeNotifier {
  final ScheduleRepository _repository = ScheduleRepository();
  List<Schedule> _schedule = [];
  bool _isLoading = false;
  String? _error;
  DateTime _selectedDate = DateTime.now();

  List<Schedule> get schedule => _schedule;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadSchedule() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _schedule = await _repository.getSchedule();
    } catch (e) {
      _error = 'Ошибка загрузки расписания: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Schedule>> getScheduleForDate(DateTime date) async {
    try {
      return await _repository.getScheduleForDate(date);
    } catch (e) {
      _error = 'Ошибка загрузки расписания на дату: $e';
      return [];
    }
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}