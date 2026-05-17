import '../models/event.dart';

class EventsRepository {
  Future<List<Event>> getEvents() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return [];
  }

  Future<List<Event>> getUpcomingEvents() async {
    final allEvents = await getEvents();
    final now = DateTime.now();
    return allEvents.where((event) => event.date.isAfter(now)).toList();
  }

  Future<List<Event>> getPastEvents() async {
    final allEvents = await getEvents();
    final now = DateTime.now();
    return allEvents.where((event) => event.date.isBefore(now)).toList();
  }

  Future<void> registerForEvent(String _) async {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}
