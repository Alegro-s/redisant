import 'package:flutter/foundation.dart';

class MainNavProvider extends ChangeNotifier {
  int _index = 0;
  bool _scrollShowcasePortfolio = false;

  int get index => _index;
  bool get shouldScrollShowcasePortfolio => _scrollShowcasePortfolio;

  void setTab(int i) {
    if (i < 0 || i > 3) return;
    if (i != 2) {
      _scrollShowcasePortfolio = false;
    }
    if (_index != i) {
      _index = i;
      notifyListeners();
    }
  }

  void goToShowcasePortfolio() {
    _scrollShowcasePortfolio = true;
    if (_index != 2) {
      _index = 2;
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  void clearShowcasePortfolioScroll() {
    if (_scrollShowcasePortfolio) {
      _scrollShowcasePortfolio = false;
      notifyListeners();
    }
  }
}
