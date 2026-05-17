import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants.dart';
import '../../data/models/schedule.dart';
import 'sheet_handle.dart';

void showScheduleDetailSheet(BuildContext context, Schedule item) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.58,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppConstants.surfaceWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              children: [
                const SheetGrabHandle(),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.subject,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: AppConstants.blockBlack,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.borderSubtle),
                      ),
                      child: Text(
                        item.type,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.blockBlack,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _detailRow(
                  PhosphorIconsRegular.clock,
                  'Время',
                  '${DateFormat('HH:mm').format(item.startTime)} — ${DateFormat('HH:mm').format(item.endTime)}',
                ),
                _detailRow(
                  PhosphorIconsRegular.user,
                  'Преподаватель',
                  item.teacher,
                ),
                _detailRow(
                  PhosphorIconsRegular.mapPin,
                  'Аудитория',
                  item.classroom,
                ),
                _detailRow(
                  PhosphorIconsRegular.calendarBlank,
                  'Дата',
                  DateFormat('EEEE, d MMMM yyyy', 'ru_RU').format(item.startTime),
                ),
                if (item.additionalInfo != null && item.additionalInfo!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 32),
                  Text(
                    item.additionalInfo!,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _detailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppConstants.secondaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.blockBlack,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
