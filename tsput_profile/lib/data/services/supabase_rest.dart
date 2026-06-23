import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/supabase_config.dart';

class SupabaseRest {
  SupabaseRest({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> get _headers => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _table(String name, {String? order, String? select}) {
    final q = <String>[];
    if (select != null) q.add('select=$select');
    if (order != null) q.add('order=$order');
    final query = q.isEmpty ? '' : '?${q.join('&')}';
    return Uri.parse('${SupabaseConfig.url}/rest/v1/$name$query');
  }

  Future<List<Map<String, dynamic>>> fetchTable(
    String table, {
    String order = 'updated_at.desc',
  }) async {
    if (!SupabaseConfig.enabled) return [];
    final response = await _client
        .get(_table(table, order: order), headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Supabase $table: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Map<String, dynamic> mapScheduleRow(Map<String, dynamic> row) => {
        'id': row['id'],
        'subject': row['subject'],
        'teacher': row['teacher'] ?? '',
        'classroom': row['classroom'] ?? '',
        'startTime': row['start_time'],
        'endTime': row['end_time'],
        'type': row['type'] ?? 'лекция',
        'additionalInfo': row['additional_info'],
      };

  static Map<String, dynamic> mapGradeRow(Map<String, dynamic> row) => {
        'id': row['id'],
        'subject': row['subject'],
        'teacher': row['teacher'] ?? '',
        'value': row['value'] ?? 0,
        'type': row['type'],
        'date': row['date'],
        'semester': row['semester'],
        'zet': row['zet'],
        'hours': row['hours'],
        'gradeLabel': row['grade_label'],
      };

  static Map<String, dynamic> mapExamRow(Map<String, dynamic> row) => {
        'id': row['id'],
        'subject': row['subject'],
        'teacher': row['teacher'] ?? '',
        'date': row['exam_date'],
        'time': row['exam_time'],
        'classroom': row['classroom'] ?? '',
        'isCompleted': row['is_completed'] ?? false,
        'type': row['type'] ?? 'экзамен',
        'grade': row['grade'],
      };

  static Map<String, dynamic> mapPortfolioRow(Map<String, dynamic> row) => {
        'id': row['id'],
        'title': row['title'],
        'category': row['category'],
        'status': row['status'],
        'date': row['item_date'],
        'source': row['source'] ?? '',
      };

  static Map<String, dynamic> mapLabRow(Map<String, dynamic> row) => {
        'id': row['id'],
        'course': row['course'],
        'title': row['title'],
        'status': row['status'],
        'teacherComment': row['teacher_comment'],
        'updatedAt': row['updated_at'],
        'deadline': row['deadline'],
        'workType': row['work_type'],
        'theme': row['theme'],
        'score': row['score'],
        'taskFileUrl': row['task_file_url'],
        'taskFileName': row['task_file_name'],
        'submissionFileUrl': row['submission_file_url'],
        'submissionFileName': row['submission_file_name'],
      };

  Future<List<Map<String, dynamic>>> fetchLabsMerged() async {
    final labs = await fetchTable('tspu_moodle_labs', order: 'updated_at.desc');
    final subs = await fetchTable('tspu_lab_submissions', order: 'submitted_at.asc');
    final latest = <String, Map<String, dynamic>>{};
    for (final sub in subs) {
      final labId = sub['lab_id']?.toString() ?? '';
      final fileName = sub['file_name']?.toString().trim() ?? '';
      if (labId.isEmpty || fileName.isEmpty) continue;
      if (!latest.containsKey(labId)) {
        latest[labId] = Map<String, dynamic>.from(sub);
        continue;
      }
      final prev = latest[labId]!['file_name']?.toString() ?? '';
      final names = prev.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (!names.contains(fileName)) names.add(fileName);
      latest[labId]!['file_name'] = names.join(', ');
      latest[labId]!['file_url'] = sub['file_url'] ?? latest[labId]!['file_url'];
      latest[labId]!['submitted_at'] = sub['submitted_at'] ?? latest[labId]!['submitted_at'];
    }
    return labs.map((row) {
      final mapped = Map<String, dynamic>.from(mapLabRow(row));
      final sub = latest[row['id']?.toString()];
      if (sub != null) {
        mapped['submissionFileName'] = sub['file_name'];
        mapped['submissionFileUrl'] = sub['file_url'];
        mapped['submittedAt'] = sub['submitted_at'];
      }
      return mapped;
    }).toList();
  }

  Uri _tableFiltered(String name, Map<String, String> filters, {String? order}) {
    final q = <String>[for (final e in filters.entries) '${e.key}=eq.${e.value}'];
    if (order != null) q.add('order=$order');
    return Uri.parse('${SupabaseConfig.url}/rest/v1/$name?${q.join('&')}');
  }

  Future<List<Map<String, dynamic>>> fetchLabComments(String labId) async {
    if (!SupabaseConfig.enabled) return [];
    final response = await _client
        .get(
          _tableFiltered('tspu_lab_comments', {'lab_id': labId}, order: 'created_at.asc'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Supabase comments: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> addLabComment(String labId, String text) async {
    if (!SupabaseConfig.enabled) {
      throw Exception('Supabase disabled');
    }
    final response = await _client
        .post(
          _table('tspu_lab_comments'),
          headers: _headers,
          body: jsonEncode([
            {'lab_id': labId, 'text': text, 'author_name': 'Студент'},
          ]),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Supabase add comment: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List && decoded.isNotEmpty) {
      final row = Map<String, dynamic>.from(decoded.first as Map);
      return {
        'id': row['id'],
        'text': row['text'],
        'timestamp': row['created_at'],
        'authorName': row['author_name'],
      };
    }
    throw Exception('Supabase add comment: empty response');
  }

  Future<Map<String, dynamic>> submitLabDirect(String labId, String fileName) async {
    if (!SupabaseConfig.enabled) {
      throw Exception('Supabase disabled');
    }
    await _client
        .post(
          _table('tspu_lab_submissions'),
          headers: _headers,
          body: jsonEncode([
            {'lab_id': labId, 'file_name': fileName, 'file_url': null},
          ]),
        )
        .timeout(const Duration(seconds: 12));
    final patchUrl = Uri.parse('${SupabaseConfig.url}/rest/v1/tspu_moodle_labs?id=eq.$labId');
    await _client
        .patch(
          patchUrl,
          headers: _headers,
          body: jsonEncode({
            'status': 'На проверке',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 12));
    final merged = await fetchLabsMerged();
    for (final row in merged) {
      if (row['id']?.toString() == labId) {
        return row;
      }
    }
    throw Exception('Lab $labId not found');
  }

  Future<Map<String, dynamic>> fetchAppRelease() async {
    if (!SupabaseConfig.enabled) {
      return {'version': '1.1.2', 'buildNumber': '3', 'notes': 'Локальная сборка'};
    }
    final rows = await fetchTable('tspu_app_release', order: 'id.asc');
    if (rows.isEmpty) {
      return {'version': '1.1.2', 'buildNumber': '3', 'notes': 'Локальная сборка'};
    }
    final row = rows.first;
    return {
      'version': row['version'] ?? '1.1.2',
      'buildNumber': row['build_number'] ?? '3',
      'notes': row['notes'],
    };
  }
}
