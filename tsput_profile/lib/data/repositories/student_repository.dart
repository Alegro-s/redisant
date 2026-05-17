import '../../core/auth/secure_storage.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class StudentRepository {
  final ApiService _apiService = ApiService();

  Future<Student> getStudentData() async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final jsonData = await _apiService.fetchStudentData(token);
    return Student.fromJson(jsonData);
  }

  Future<void> updateStudentInfo(Map<String, dynamic> updates) async {
    await Future.delayed(Duration(seconds: 1));
  }
}