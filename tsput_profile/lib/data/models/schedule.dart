class Schedule {
  final String id;
  final String subject;
  final String teacher;
  final String classroom;
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final String? additionalInfo;

  Schedule({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.classroom,
    required this.startTime,
    required this.endTime,
    required this.type,
    this.additionalInfo,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      teacher: json['teacher'] ?? '',
      classroom: json['classroom'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      type: json['type'] ?? 'лекция',
      additionalInfo: json['additionalInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'teacher': teacher,
      'classroom': classroom,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'type': type,
      'additionalInfo': additionalInfo,
    };
  }
}