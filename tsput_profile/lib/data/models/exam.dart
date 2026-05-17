class Exam {
  final String id;
  final String subject;
  final String teacher;
  final String date;
  final String time;
  final String classroom;
  final int? grade;
  final bool isCompleted;
  final String type;

  Exam({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.date,
    required this.time,
    required this.classroom,
    this.grade,
    required this.isCompleted,
    required this.type,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      teacher: json['teacher'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      classroom: json['classroom'] ?? '',
      grade: json['grade'],
      isCompleted: json['isCompleted'] ?? false,
      type: json['type'] ?? 'экзамен',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'teacher': teacher,
      'date': date,
      'time': time,
      'classroom': classroom,
      'grade': grade,
      'isCompleted': isCompleted,
      'type': type,
    };
  }
}