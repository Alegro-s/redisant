class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String organizer;
  final String type;
  final int points;
  final bool attended;
  final String? certificateUrl;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.organizer,
    required this.type,
    required this.points,
    required this.attended,
    this.certificateUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      date: DateTime.parse(json['date']),
      location: json['location'] ?? '',
      organizer: json['organizer'] ?? '',
      type: json['type'] ?? '',
      points: json['points'] ?? 0,
      attended: json['attended'] ?? false,
      certificateUrl: json['certificateUrl'],
    );
  }
}