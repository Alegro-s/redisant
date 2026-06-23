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

  Future<LabWork> submitLab(
    String labId, {
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final json = await _apiService.submitLab(
      token,
      labId,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    return LabWork.fromJson(json);
  }

  Future<List<LabComment>> getComments(String labId) async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final jsonList = await _apiService.fetchLabComments(token, labId);
    return jsonList
        .map((json) => LabComment.fromJson(json as Map<String, dynamic>))
        .where((c) => c.isFromTeacher)
        .toList();
  }
}
