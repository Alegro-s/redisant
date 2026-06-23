import 'package:flutter/foundation.dart';

import '../../data/models/lab_work.dart';
import '../../data/repositories/labs_repository.dart';

class LabsProvider with ChangeNotifier {
  final LabsRepository _repository = LabsRepository();
  List<LabWork> _labs = [];
  bool _isLoading = false;
  String? _error;

  List<LabWork> get labs => _labs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalLabs => _labs.length;
  int get passedLabs => _labs.where((l) => l.isPositive).length;
  int get submittedLabs => _labs.where((l) => l.isSubmittedForGrading).length;

  List<LabNotification> get notifications {
    final items = <LabNotification>[];
    final seenFeedback = <String>{};

    for (final lab in _labs) {
      if (lab.isOverdue) {
        items.add(
          LabNotification(
            labId: lab.id,
            labTitle: lab.title,
            title: 'Просрочено',
            message: '${lab.title} · срок ${lab.deadline != null ? _fmtDate(lab.deadline!) : '—'}',
            kind: LabNotificationKind.overdue,
            at: lab.deadline,
          ),
        );
      }
      if (lab.isSubmittedForGrading && !lab.isPositive) {
        items.add(
          LabNotification(
            labId: lab.id,
            labTitle: lab.title,
            title: 'Отправлено для оценивания',
            message: lab.submissionFileNames.isNotEmpty
                ? lab.submissionFileNames.join(', ')
                : lab.title,
            kind: LabNotificationKind.submitted,
            at: lab.updatedAt,
          ),
        );
      }
      final feedback = lab.teacherComment?.trim();
      if (feedback != null && feedback.isNotEmpty && seenFeedback.add('${lab.id}:$feedback')) {
        items.add(
          LabNotification(
            labId: lab.id,
            labTitle: lab.title,
            title: 'Отзыв преподавателя',
            message: feedback,
            kind: LabNotificationKind.teacherFeedback,
            at: lab.updatedAt,
          ),
        );
      }
      for (final comment in lab.teacherCommentsOnly) {
        final key = '${lab.id}:${comment.id}';
        if (!seenFeedback.add(key)) continue;
        if (feedback != null && comment.text.trim() == feedback) continue;
        items.add(
          LabNotification(
            labId: lab.id,
            labTitle: lab.title,
            title: 'Комментарий преподавателя',
            message: comment.text,
            kind: LabNotificationKind.teacherFeedback,
            at: comment.timestamp,
          ),
        );
      }
    }
    return items;
  }

  int get notificationCount => notifications.length;

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  Future<void> loadLabs() async {
    await Future<void>.delayed(Duration.zero);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _labs = await _repository.getLabs();
    } catch (e) {
      _error = 'Ошибка загрузки лабораторных (Moodle): $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitLab(
    String labId, {
    String? filePath,
    List<int>? fileBytes,
    required String fileName,
  }) async {
    _error = null;
    notifyListeners();
    try {
      final updated = await _repository.submitLab(
        labId,
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      _replaceLab(updated);
    } catch (e) {
      _error = 'Ошибка отправки работы: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> loadComments(String labId) async {
    try {
      final comments = await _repository.getComments(labId);
      final teacherOnly = comments.where((c) => c.isFromTeacher).toList();
      final idx = _labs.indexWhere((l) => l.id == labId);
      if (idx != -1) {
        _labs[idx] = _labs[idx].copyWith(comments: teacherOnly);
        notifyListeners();
      }
    } catch (e) {
      _error = 'Ошибка загрузки отзывов: $e';
      notifyListeners();
    }
  }

  Future<void> saveSubmission(
    String labId, {
    required List<({String? filePath, List<int>? fileBytes, String fileName})> files,
  }) async {
    if (files.isEmpty) {
      throw StateError('Нет файлов для отправки');
    }
    _error = null;
    notifyListeners();
    try {
      for (final file in files) {
        await _repository.submitLab(
          labId,
          filePath: file.filePath,
          fileBytes: file.fileBytes,
          fileName: file.fileName,
        );
      }
      await loadLabs();
    } catch (e) {
      _error = 'Ошибка сохранения ответа: $e';
      notifyListeners();
      rethrow;
    }
  }

  void _replaceLab(LabWork updated) {
    final idx = _labs.indexWhere((l) => l.id == updated.id);
    if (idx == -1) {
      _labs = [updated, ..._labs];
    } else {
      final prevComments = _labs[idx].comments;
      _labs[idx] = updated.copyWith(comments: prevComments.isNotEmpty ? prevComments : updated.comments);
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
