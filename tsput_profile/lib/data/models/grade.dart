class Grade {
  final String id;
  final String subject;
  final String teacher;
  final int value;
  final String type;
  final DateTime date;
  final int? semester;
  final int? zet;
  final int? hours;
  final String? gradeLabel;

  Grade({
    required this.id,
    required this.subject,
    required this.teacher,
    required this.value,
    required this.type,
    required this.date,
    this.semester,
    this.zet,
    this.hours,
    this.gradeLabel,
  });

  static int? _optInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  factory Grade.fromJson(Map<String, dynamic> json) {
    return Grade(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      teacher: json['teacher']?.toString() ?? '',
      value: _optInt(json['value']) ?? 0,
      type: json['type']?.toString() ?? 'экзамен',
      date: DateTime.parse(json['date'].toString()),
      semester: _optInt(json['semester']),
      zet: _optInt(json['zet']),
      hours: _optInt(json['hours']),
      gradeLabel: json['gradeLabel']?.toString() ?? json['grade_label']?.toString(),
    );
  }

  String get displayGrade => gradeLabel ?? (value > 0 ? value.toString() : '—');

  bool get isNumericScore => value >= 1 && value <= 5;
}