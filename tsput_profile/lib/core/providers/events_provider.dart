import 'package:flutter/foundation.dart';
import '../../data/models/event.dart';
import '../../data/repositories/events_repository.dart';

class EventsProvider with ChangeNotifier {
  final EventsRepository _repository = EventsRepository();
  List<Event> _upcomingEvents = [];
  List<Event> _pastEvents = [];
  bool _isLoading = false;
  String? _error;

  List<Event> get upcomingEvents => _upcomingEvents;
  List<Event> get pastEvents => _pastEvents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _upcomingEvents = await _repository.getUpcomingEvents();
      _pastEvents = await _repository.getPastEvents();
    } catch (e) {
      _error = 'Ошибка загрузки мероприятий: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> registerForEvent(String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.registerForEvent(eventId);
      await loadEvents();
    } catch (e) {
      _error = 'Ошибка регистрации на мероприятие: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}