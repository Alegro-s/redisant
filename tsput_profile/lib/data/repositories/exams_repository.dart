import 'package:intl/intl.dart';
import '../../core/auth/secure_storage.dart';
import '../models/exam.dart';
import '../services/api_service.dart';

class ExamsRepository {
  final ApiService _apiService = ApiService();

  Future<List<Exam>> getExams() async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final jsonList = await _apiService.fetchExams(token);
    return jsonList.map((json) => Exam.fromJson(json)).toList();
  }

  Future<List<Exam>> getUpcomingExams() async {
    final allExams = await getExams();
    final now = DateTime.now();

    return allExams.where((exam) {
      if (exam.isCompleted) return false;

      try {
        final examDate = DateFormat('dd.MM.yyyy').parse(exam.date);
        return examDate.isAfter(now) || examDate.isAtSameMomentAs(now);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Future<List<Exam>> getCompletedExams() async {
    final allExams = await getExams();
    return allExams.where((exam) => exam.isCompleted).toList();
  }
}