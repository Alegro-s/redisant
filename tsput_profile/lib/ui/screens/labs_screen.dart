import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/providers/labs_provider.dart';
import '../../data/models/lab_work.dart';

class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      appBar: AppBar(
        title: const Text('Лабораторные · Moodle'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => context.read<LabsProvider>().loadLabs(),
          ),
        ],
      ),
      body: Consumer<LabsProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading && prov.labs.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppConstants.blockBlack));
          }
          if (prov.error != null && prov.labs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.warningCircle, size: 48, color: AppConstants.terracotta),
                    const SizedBox(height: 12),
                    Text(prov.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => prov.loadLabs(),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (prov.labs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Пока нет заданий из Moodle.\nПосле настройки сервера список подтянется автоматически.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppConstants.secondaryColor, height: 1.45),
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: AppConstants.blockBlack,
            onRefresh: () => prov.loadLabs(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _SummaryStrip(passed: prov.passedLabs, total: prov.totalLabs),
                const SizedBox(height: 16),
                for (final lab in prov.labs) _LabCard(lab: lab),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.passed, required this.total});

  final int passed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : passed / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.flask, color: AppConstants.blockBlack),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Прогресс по статусам Moodle',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              Text(
                '$passed / $total',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppConstants.borderSubtle,
                  color: AppConstants.blockBlack,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard({required this.lab});

  final LabWork lab;

  @override
  Widget build(BuildContext context) {
    final due = lab.deadline ?? lab.updatedAt;
    final dueStr = DateFormat('dd.MM.yy').format(due);
    final type = lab.workType ?? 'ЛР';
    final theme = lab.theme ?? lab.title;
    final scoreStr = lab.score?.toString() ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppConstants.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppConstants.borderSubtle),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(context, lab),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      lab.course,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                  _StatusChip(lab: lab),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                lab.title,
                style: TextStyle(fontSize: 14, color: AppConstants.secondaryColor, height: 1.3),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 36,
                  dataRowMinHeight: 40,
                  dataRowMaxHeight: 56,
                  columns: const [
                    DataColumn(label: Text('Срок')),
                    DataColumn(label: Text('Тип')),
                    DataColumn(label: Text('Работа')),
                    DataColumn(label: Text('Тема')),
                    DataColumn(label: Text('Баллы')),
                  ],
                  rows: [
                    DataRow(
                      cells: [
                        DataCell(Text(dueStr)),
                        DataCell(Text(type)),
                        DataCell(Text(lab.title, maxLines: 2)),
                        DataCell(Text(theme, maxLines: 2)),
                        DataCell(Text(scoreStr)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, LabWork lab) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppConstants.surfaceWhite,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lab.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(lab.course, style: TextStyle(color: AppConstants.secondaryColor)),
                const SizedBox(height: 16),
                Text('Статус: ${lab.status}', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (lab.teacherComment != null && lab.teacherComment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Комментарий преподавателя',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppConstants.secondaryColor,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(lab.teacherComment!, style: const TextStyle(height: 1.4)),
                ],
                const SizedBox(height: 12),
                Text(
                  'Обновлено: ${DateFormat('dd.MM.yyyy HH:mm').format(lab.updatedAt)}',
                  style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.lab});

  final LabWork lab;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg = AppConstants.surfaceWhite;
    if (lab.needsAttention) {
      bg = AppConstants.terracotta;
    } else if (lab.isPositive) {
      bg = const Color(0xFF1B5E20);
    } else {
      bg = AppConstants.blockBlack;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        lab.status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
