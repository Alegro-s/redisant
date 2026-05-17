class LabWork {
  final String id;
  final String title;
  final String course;
  final String status;
  final String? teacherComment;
  final DateTime updatedAt;
  final DateTime? deadline;
  final String? workType;
  final String? theme;
  final int? score;

  const LabWork({
    required this.id,
    required this.title,
    required this.course,
    required this.status,
    this.teacherComment,
    required this.updatedAt,
    this.deadline,
    this.workType,
    this.theme,
    this.score,
  });

  static int? _optInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory LabWork.fromJson(Map<String, dynamic> json) {
    final updated = _parseDt(json['updatedAt']) ?? DateTime.now();
    return LabWork(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      status: json['status']?.toString() ?? '—',
      teacherComment: json['teacherComment']?.toString(),
      updatedAt: updated,
      deadline: _parseDt(json['deadline']) ?? _parseDt(json['dueDate']),
      workType: json['workType']?.toString() ?? json['type']?.toString(),
      theme: json['theme']?.toString(),
      score: _optInt(json['score'] ?? json['grade']),
    );
  }

  bool get isPositive {
    final t = status.toLowerCase();
    if (t.contains('принят') || t.contains('зачт') || t.contains('accepted')) return true;
    if (score != null && score! >= 3) return true;
    return false;
  }

  bool get needsAttention {
    final t = status.toLowerCase();
    return t.contains('возврат') || t.contains('отклон') || t.contains('reject');
  }
}
