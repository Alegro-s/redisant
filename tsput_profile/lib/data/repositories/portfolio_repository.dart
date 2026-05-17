import '../../core/auth/secure_storage.dart';
import '../models/portfolio_item.dart';
import '../services/api_service.dart';

class PortfolioRepository {
  final ApiService _apiService = ApiService();

  Future<List<PortfolioItem>> getPortfolio() async {
    final token = await SecureStorage.getAuthToken() ?? '';
    final jsonList = await _apiService.fetchPortfolio(token);
    return jsonList
        .map((item) => PortfolioItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
