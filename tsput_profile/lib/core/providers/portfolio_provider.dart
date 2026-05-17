import 'package:flutter/foundation.dart';
import '../../data/models/portfolio_item.dart';
import '../../data/repositories/portfolio_repository.dart';

class PortfolioProvider with ChangeNotifier {
  final PortfolioRepository _repository = PortfolioRepository();
  List<PortfolioItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<PortfolioItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadPortfolio() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _repository.getPortfolio();
    } catch (e) {
      _error = 'Ошибка загрузки портфолио: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
