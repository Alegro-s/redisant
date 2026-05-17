import '../../core/auth/secure_storage.dart';
import '../models/lab_work.dart';
import '../services/api_service.dart';

class LabsRepository {
  final ApiService _apiService = ApiService();

  Future<List<LabWork>> getLabs() async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final jsonList = await _apiService.fetchMoodleLabs(token);
    return jsonList.map((json) => LabWork.fromJson(json as Map<String, dynamic>)).toList();
  }
}
