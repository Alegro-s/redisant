import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/schedule.dart';

class ScheduleWeekPlanPdf {
  ScheduleWeekPlanPdf._();

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static List<Schedule> _forDay(DateTime day, List<Schedule> all) {
    final key = _dateOnly(day);
    return all.where((s) => _dateOnly(s.startTime) == key).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static String _typeShort(String type) {
    final t = type.toLowerCase();
    if (t.contains('лек')) return 'лек.';
    if (t.contains('лаб')) return 'лаб.';
    if (t.contains('прак')) return 'пр.';
    return type;
  }

  static String _typeRu(String type) {
    final t = type.toLowerCase();
    if (t.contains('лек')) return 'Лекция';
    if (t.contains('лаб')) return 'Лабораторная';
    if (t.contains('прак')) return 'Практика';
    return type;
  }

  static Future<Uint8List> build({
    required DateTime weekMonday,
    required List<Schedule> schedule,
    required String headerTitle,
    required String groupLine,
    String? studentName,
    String? typeFilterLabel,
  }) async {
    final baseFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final mono = weekMonday;
    final sun = mono.add(const Duration(days: 6));
    final weekLabel =
        '${DateFormat('dd.MM.yyyy').format(mono)} — ${DateFormat('dd.MM.yyyy').format(sun)}';

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final blocks = <pw.Widget>[
            pw.Text(
              'Расписание · план недели',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(headerTitle, style: const pw.TextStyle(fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text(
              '$groupLine · $weekLabel',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
            if (studentName != null && studentName.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(studentName, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ],
            if (typeFilterLabel != null && typeFilterLabel.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Фильтр: $typeFilterLabel', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
            pw.SizedBox(height: 4),
            pw.Text(
              'Сформировано: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
            pw.SizedBox(height: 16),
          ];

          for (var i = 0; i < 7; i++) {
            final day = mono.add(Duration(days: i));
            blocks.add(_dayTable(context, day: day, items: _forDay(day, schedule), groupLine: groupLine));
            blocks.add(pw.SizedBox(height: 12));
          }

          return blocks;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _dayTable(
    pw.Context context, {
    required DateTime day,
    required List<Schedule> items,
    required String groupLine,
  }) {
    final dayTitle = DateFormat('EEEE, d MMMM yyyy', 'ru_RU').format(day);
    final dateShort = DateFormat('dd.MM').format(day);
    final capitalized = dayTitle.isEmpty ? dayTitle : '${dayTitle[0].toUpperCase()}${dayTitle.substring(1)}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            border: pw.Border.all(color: PdfColors.grey400),
          ),
          child: pw.Column(
            children: [
              pw.Text(
                capitalized,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$groupLine · $dateShort',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                left: const pw.BorderSide(color: PdfColors.grey400),
                right: const pw.BorderSide(color: PdfColors.grey400),
                bottom: const pw.BorderSide(color: PdfColors.grey400),
              ),
            ),
            child: pw.Text(
              'Нет занятий',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(2.4),
              2: const pw.FlexColumnWidth(0.7),
              3: const pw.FlexColumnWidth(0.9),
              4: const pw.FlexColumnWidth(1.4),
            },
            headers: ['Время', 'Предмет', 'Тип', 'Ауд.', 'Преподаватель'],
            data: items
                .map(
                  (e) => [
                    '${DateFormat('HH:mm').format(e.startTime)} — ${DateFormat('HH:mm').format(e.endTime)}',
                    e.subject,
                    _typeShort(e.type),
                    e.classroom.isEmpty ? '—' : e.classroom,
                    e.teacher.isEmpty ? '—' : e.teacher,
                  ],
                )
                .toList(),
          ),
      ],
    );
  }

  static String? typeFilterLabel(String? filter) {
    if (filter == null) return null;
    return _typeRu(filter);
  }
}
