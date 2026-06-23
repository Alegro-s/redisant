class LabComment {
  final String id;
  final String text;
  final DateTime timestamp;
  final String authorName;

  const LabComment({
    required this.id,
    required this.text,
    required this.timestamp,
    this.authorName = 'Преподаватель',
  });

  bool get isFromTeacher {
    final a = authorName.toLowerCase();
    if (a.contains('препод') || a.contains('teacher') || a.contains('lecturer')) return true;
    return !a.contains('студент') && !a.contains('student');
  }

  factory LabComment.fromJson(Map<String, dynamic> json) {
    return LabComment(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      authorName: json['authorName']?.toString() ?? json['author_name']?.toString() ?? 'Преподаватель',
    );
  }
}

enum LabNotificationKind { overdue, submitted, teacherFeedback }

class LabNotification {
  const LabNotification({
    required this.labId,
    required this.labTitle,
    required this.title,
    required this.message,
    required this.kind,
    this.at,
  });

  final String labId;
  final String labTitle;
  final String title;
  final String message;
  final LabNotificationKind kind;
  final DateTime? at;
}

class LabWork {
  final String id;
  final String title;
  final String course;
  final String status;
  final String? teacherComment;
  final DateTime updatedAt;
  final DateTime? deadline;
  final DateTime? submittedAt;
  final String? workType;
  final String? theme;
  final int? score;
  final String? taskFileUrl;
  final String? taskFileName;
  final String? submissionFileUrl;
  final String? submissionFileName;
  final List<LabComment> comments;

  const LabWork({
    required this.id,
    required this.title,
    required this.course,
    required this.status,
    this.teacherComment,
    required this.updatedAt,
    this.deadline,
    this.submittedAt,
    this.workType,
    this.theme,
    this.score,
    this.taskFileUrl,
    this.taskFileName,
    this.submissionFileUrl,
    this.submissionFileName,
    this.comments = const [],
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
    final rawComments = json['comments'];
    final comments = rawComments is List
        ? rawComments
            .whereType<Map>()
            .map((e) => LabComment.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <LabComment>[];
    return LabWork(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      course: json['course']?.toString() ?? '',
      status: json['status']?.toString() ?? '—',
      teacherComment: json['teacherComment']?.toString(),
      updatedAt: updated,
      deadline: _parseDt(json['deadline']) ?? _parseDt(json['dueDate']),
      submittedAt: _parseDt(json['submittedAt']) ?? _parseDt(json['submitted_at']),
      workType: json['workType']?.toString() ?? json['type']?.toString(),
      theme: json['theme']?.toString(),
      score: _optInt(json['score'] ?? json['grade']),
      taskFileUrl: json['taskFileUrl']?.toString(),
      taskFileName: json['taskFileName']?.toString(),
      submissionFileUrl: json['submissionFileUrl']?.toString(),
      submissionFileName: json['submissionFileName']?.toString(),
      comments: comments,
    );
  }

  LabWork copyWith({
    String? status,
    String? submissionFileUrl,
    String? submissionFileName,
    List<LabComment>? comments,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) {
    return LabWork(
      id: id,
      title: title,
      course: course,
      status: status ?? this.status,
      teacherComment: teacherComment,
      updatedAt: updatedAt ?? this.updatedAt,
      deadline: deadline,
      submittedAt: submittedAt ?? this.submittedAt,
      workType: workType,
      theme: theme,
      score: score,
      taskFileUrl: taskFileUrl,
      taskFileName: taskFileName,
      submissionFileUrl: submissionFileUrl ?? this.submissionFileUrl,
      submissionFileName: submissionFileName ?? this.submissionFileName,
      comments: comments ?? this.comments,
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
    return t.contains('возврат') || t.contains('отклон') || t.contains('reject') || t.contains('правк');
  }

  bool get isSubmitted => submissionFileName != null && submissionFileName!.isNotEmpty;

  List<String> get submissionFileNames {
    if (submissionFileName == null || submissionFileName!.isEmpty) return const [];
    return submissionFileName!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<LabComment> get teacherCommentsOnly => comments.where((c) => c.isFromTeacher).toList();

  bool get isSubmittedForGrading {
    final t = status.toLowerCase();
    return isSubmitted || t.contains('провер') || t.contains('отправ');
  }

  bool get isOverdue {
    if (isPositive || isSubmittedForGrading) return false;
    if (deadline == null) return false;
    return deadline!.isBefore(DateTime.now());
  }

  String get submissionStatusLabel {
    if (isPositive) return 'Принято';
    if (needsAttention) return 'Требуются правки';
    final t = status.toLowerCase();
    if (t.contains('провер') || (isSubmitted && !isPositive && !needsAttention)) {
      return 'Отправлено для оценивания';
    }
    if (isOverdue) return 'Просрочено';
    if (isSubmitted) return 'Отправлено для оценивания';
    return 'Не отправлено';
  }

  String get gradingStatusLabel {
    if (score != null || isPositive) return 'Оценено';
    if (isSubmittedForGrading && !isPositive) return 'Не оценено';
    return '—';
  }

  bool get submissionStatusPositive {
    final label = submissionStatusLabel;
    return label.contains('Отправлено') || label.contains('Принято');
  }

  bool get isReviewed => isPositive || needsAttention || score != null;

  DateTime? get reviewedAt => isReviewed ? updatedAt : null;

  DateTime? get primaryListDate {
    if (reviewedAt != null) return reviewedAt;
    if (submittedAt != null) return submittedAt;
    return deadline;
  }

  String get primaryListDateLabel {
    if (reviewedAt != null) return 'Проверено';
    if (submittedAt != null) return 'Сдано';
    if (deadline != null) return 'Крайний срок';
    return 'Дата';
  }

  String get displayStatusLabel {
    if (isPositive) return 'Принято';
    if (needsAttention) return 'Требуются правки';
    final t = status.toLowerCase();
    if (t.contains('провер')) return 'На проверке';
    if (isSubmittedForGrading) return 'Отправлено для оценивания';
    if (isOverdue) return 'Просрочено';
    if (isSubmitted) return 'Отправлено для оценивания';
    return 'Не отправлено';
  }
}
