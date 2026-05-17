import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/models/schedule.dart';

class WeekSchedulePlanDayTable extends StatelessWidget {
  const WeekSchedulePlanDayTable({
    super.key,
    required this.day,
    required this.items,
    required this.headerTitle,
    required this.groupLine,
  });

  final DateTime day;
  final List<Schedule> items;
  final String headerTitle;
  final String groupLine;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd.MM').format(day);
    final sorted = List<Schedule>.from(items)..sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppConstants.surfaceWhite,
            border: Border.all(color: AppConstants.borderSubtle),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _HeaderCell(text: headerTitle, big: true),
              _HeaderCell(text: '$groupLine · $dateStr', big: false),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Нет занятий',
                    style: TextStyle(color: AppConstants.secondaryColor, fontSize: 15),
                  ),
                )
              else
                for (final e in sorted)
                  _ScheduleRow(
                    time:
                        '${DateFormat('HH:mm').format(e.startTime)} — ${DateFormat('HH:mm').format(e.endTime)}',
                    title: e.subject,
                    subtitle:
                        '${_typeShort(e.type)} · ${e.classroom.isEmpty ? 'ауд. —' : e.classroom}'
                        '${e.teacher.isNotEmpty ? ' · ${e.teacher}' : ''}',
                    accent: _rowAccent(e),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _typeShort(String type) {
    final t = type.toLowerCase();
    if (t.contains('лек')) return 'лек.';
    if (t.contains('лаб')) return 'лаб.';
    if (t.contains('прак')) return 'пр.';
    return type;
  }

  static Color _rowAccent(Schedule e) {
    final t = e.type.toLowerCase();
    if (t.contains('лаб')) return AppConstants.terracotta;
    if (t.contains('лек')) return const Color(0xFF1B8C36);
    return AppConstants.blockBlack;
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text, required this.big});

  final String text;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: big ? 12 : 10),
      decoration: BoxDecoration(
        color: AppConstants.terracottaMuted,
        border: Border(bottom: BorderSide(color: AppConstants.borderSubtle)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: big ? 20 : 16,
          color: AppConstants.blockBlack,
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String time;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppConstants.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, height: 1.15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(color: AppConstants.secondaryColor, fontSize: 13, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
