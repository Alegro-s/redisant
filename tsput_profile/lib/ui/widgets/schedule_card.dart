import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/providers/schedule_provider.dart';
import '../../data/models/schedule.dart';
import 'schedule_detail_sheet.dart';

class ScheduleList extends StatelessWidget {
  const ScheduleList({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = context.watch<ScheduleProvider>();
    final todaySchedule = _getTodaySchedule(scheduleProvider.schedule);

    if (scheduleProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppConstants.blockBlack),
        ),
      );
    }

    if (todaySchedule.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppConstants.surfaceMuted,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            border: Border.all(color: const Color(0xFFE8E8E6)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsRegular.calendarCheck, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Нет занятий на сегодня',
                style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: todaySchedule.map((item) => _buildScheduleCard(context, item)).toList(),
    );
  }

  List<Schedule> _getTodaySchedule(List<Schedule> allSchedule) {
    final now = DateTime.now();
    return allSchedule.where((item) {
      return item.startTime.year == now.year &&
          item.startTime.month == now.month &&
          item.startTime.day == now.day;
    }).toList();
  }

  Widget _buildScheduleCard(BuildContext context, Schedule item) {
    final timeFormat = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showScheduleDetailSheet(context, item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.blockBlack,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppConstants.blockBlackElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeFormat.format(item.startTime),
                        style: const TextStyle(
                          color: AppConstants.onBlock,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        timeFormat.format(item.endTime),
                        style: const TextStyle(
                          color: AppConstants.onBlockSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.subject,
                        style: const TextStyle(
                          color: AppConstants.onBlock,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.teacher} · ${item.type}',
                        style: const TextStyle(
                          color: AppConstants.onBlockSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (item.additionalInfo != null && item.additionalInfo!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.additionalInfo!,
                          style: const TextStyle(
                            color: AppConstants.onBlockSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getTypeColor(item.type),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.classroom,
                        style: const TextStyle(
                          color: AppConstants.surfaceWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Icon(PhosphorIconsRegular.caretRight, color: AppConstants.onBlockSecondary, size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'лекция':
        return const Color(0xFF3D3D3D);
      case 'практика':
        return const Color(0xFF525252);
      case 'лабораторная':
        return const Color(0xFF666666);
      default:
        return AppConstants.secondaryColor;
    }
  }
}
