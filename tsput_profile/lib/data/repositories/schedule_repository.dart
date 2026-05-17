import '../../core/auth/secure_storage.dart';
import '../models/schedule.dart';
import '../services/api_service.dart';

class ScheduleRepository {
  final ApiService _apiService = ApiService();

  Future<List<Schedule>> getSchedule() async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final jsonList = await _apiService.fetchSchedule(token);
    return jsonList.map((json) => Schedule.fromJson(json)).toList();
  }

  Future<List<Schedule>> getScheduleForDate(DateTime date) async {
    final allSchedule = await getSchedule();
    return allSchedule.where((item) {
      return item.startTime.year == date.year &&
          item.startTime.month == date.month &&
          item.startTime.day == date.day;
    }).toList();
  }
}