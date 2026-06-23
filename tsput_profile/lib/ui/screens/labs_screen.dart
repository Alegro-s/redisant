import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/providers/labs_provider.dart';
import '../../data/models/lab_work.dart';
import '../../data/services/file_service.dart';

String _labShortDate(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('dd.MM.yyyy').format(dt.toLocal());
}

String _labLongDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('d MMMM yyyy, HH:mm', 'ru_RU').format(dt.toLocal());
}

Color _labStatusColor(LabWork lab) {
  if (lab.isPositive) return const Color(0xFF2E7D32);
  if (lab.needsAttention || lab.isOverdue) return AppConstants.terracotta;
  if (lab.isSubmittedForGrading) return AppConstants.blockBlack;
  return AppConstants.secondaryColor;
}

class LabsScreen extends StatelessWidget {
  const LabsScreen({super.key});

  void _openNotifications(BuildContext context) {
    final prov = context.read<LabsProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppConstants.surfaceWhite,
      builder: (ctx) => _LabNotificationsSheet(
        notifications: prov.notifications,
        onOpenLab: (labId) {
          Navigator.pop(ctx);
          final lab = prov.labs.firstWhere((l) => l.id == labId, orElse: () => prov.labs.first);
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => LabWorkDetailScreen(labId: lab.id)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      appBar: AppBar(
        title: const Text('Лабораторные · Moodle'),
        actions: [
          Consumer<LabsProvider>(
            builder: (context, prov, _) {
              final count = prov.notificationCount;
              return IconButton(
                tooltip: 'Уведомления',
                onPressed: () => _openNotifications(context),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 9 ? '9+' : '$count'),
                  child: const Icon(PhosphorIconsRegular.bell),
                ),
              );
            },
          ),
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
                    FilledButton(onPressed: () => prov.loadLabs(), child: const Text('Повторить')),
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
                  'Пока нет заданий из Moodle.',
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
                _SummaryStrip(passed: prov.passedLabs, submitted: prov.submittedLabs, total: prov.totalLabs),
                if (prov.error != null) ...[
                  const SizedBox(height: 12),
                  Text(prov.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ],
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

class _LabNotificationsSheet extends StatelessWidget {
  const _LabNotificationsSheet({required this.notifications, required this.onOpenLab});

  final List<LabNotification> notifications;
  final void Function(String labId) onOpenLab;

  IconData _icon(LabNotificationKind kind) {
    switch (kind) {
      case LabNotificationKind.overdue:
        return PhosphorIconsRegular.clockCountdown;
      case LabNotificationKind.submitted:
        return PhosphorIconsRegular.paperPlaneTilt;
      case LabNotificationKind.teacherFeedback:
        return PhosphorIconsRegular.chatsCircle;
    }
  }

  Color _accent(LabNotificationKind kind) {
    switch (kind) {
      case LabNotificationKind.overdue:
        return AppConstants.terracotta;
      case LabNotificationKind.submitted:
        return const Color(0xFF2E7D32);
      case LabNotificationKind.teacherFeedback:
        return AppConstants.blockBlack;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Уведомления', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              'Комментарии преподавателя и статус сдачи',
              style: TextStyle(color: AppConstants.secondaryColor, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Новых уведомлений нет',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppConstants.secondaryColor),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    return Material(
                      color: AppConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onOpenLab(n.labId),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(_icon(n.kind), color: _accent(n.kind), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                      n.labTitle,
                                      style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(n.message, style: const TextStyle(height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.passed, required this.submitted, required this.total});

  final int passed;
  final int submitted;
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
                child: Text('Прогресс по лабораторным', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              Text('$passed / $total', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Отправлено работ: $submitted', style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)),
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

  Future<void> _downloadTask(BuildContext context) async {
    final url = lab.taskFileUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файл задания не приложен')));
      return;
    }
    if (url.startsWith('http')) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final fileService = FileService();
    try {
      final saved = await fileService.downloadFile(url, lab.taskFileName ?? 'task.pdf');
      await fileService.saveToDownloads(saved.path, lab.taskFileName ?? 'task.pdf');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Задание сохранено')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _labStatusColor(lab);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppConstants.borderSubtle),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => LabWorkDetailScreen(labId: lab.id)),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (lab.workType != null)
                        Container(
                          margin: const EdgeInsets.only(right: 8, top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppConstants.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            lab.workType!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          lab.course,
                          style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(lab.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.25)),
                  const SizedBox(height: 10),
                  _LabStatusBadge(lab: lab, compact: true),
                  if (lab.submissionFileNames.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      lab.submissionFileNames.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabDateMeta(lab: lab),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _downloadTask(context),
                      icon: const Icon(PhosphorIconsRegular.downloadSimple, size: 18),
                      label: const Text('Скачать задание'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LabWorkDetailScreen extends StatefulWidget {
  const LabWorkDetailScreen({super.key, required this.labId});

  final String labId;

  @override
  State<LabWorkDetailScreen> createState() => _LabWorkDetailScreenState();
}

class _LabWorkDetailScreenState extends State<LabWorkDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LabsProvider>().loadComments(widget.labId);
    });
  }

  Future<void> _downloadTask(LabWork lab) async {
    final url = lab.taskFileUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Файл задания не приложен')));
      return;
    }
    if (url.startsWith('http')) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    final fileService = FileService();
    try {
      final saved = await fileService.downloadFile(url, lab.taskFileName ?? 'task.pdf');
      await fileService.saveToDownloads(saved.path, lab.taskFileName ?? 'task.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Задание сохранено')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void _openSubmission(LabWork lab) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => LabSubmissionScreen(labId: lab.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LabsProvider>();
    final lab = prov.labs.firstWhere(
      (l) => l.id == widget.labId,
      orElse: () => prov.labs.isNotEmpty ? prov.labs.first : _emptyLab(widget.labId),
    );
    final accent = _labStatusColor(lab);

    return Scaffold(
      backgroundColor: AppConstants.surfaceMuted,
      appBar: AppBar(
        backgroundColor: AppConstants.surfaceWhite,
        title: Text(lab.course, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _LabStatusBanner(lab: lab, accent: accent),
          const SizedBox(height: 14),
          if (lab.taskFileName != null) ...[
            _LabSectionCard(
              title: 'Материалы',
              child: Material(
                color: AppConstants.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _downloadTask(lab),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppConstants.terracotta.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(PhosphorIconsRegular.filePdf, color: AppConstants.terracotta),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Файл задания', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(lab.taskFileName!, style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Icon(PhosphorIconsRegular.downloadSimple, color: AppConstants.secondaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _LabSectionCard(
            title: 'Состояние ответа',
            child: _LabDetailsPanel(lab: lab),
          ),
          const SizedBox(height: 14),
          _LabSectionCard(
            title: 'Отзыв преподавателя',
            child: _FeedbackBlock(lab: lab),
          ),
          const SizedBox(height: 20),
          if (!lab.isPositive)
            FilledButton.icon(
              onPressed: () => _openSubmission(lab),
              icon: const Icon(PhosphorIconsRegular.uploadSimple),
              label: Text(lab.isSubmitted ? 'Изменить ответ на задание' : 'Добавить ответ на задание'),
            ),
        ],
      ),
    );
  }

  LabWork _emptyLab(String id) => LabWork(
        id: id,
        title: '—',
        course: '—',
        status: '—',
        updatedAt: DateTime.now(),
      );
}

class _LabStatusBanner extends StatelessWidget {
  const _LabStatusBanner({required this.lab, required this.accent});

  final LabWork lab;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lab.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, height: 1.25)),
          if (lab.theme != null && lab.theme!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(lab.theme!, style: TextStyle(color: AppConstants.secondaryColor, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lab.displayStatusLabel, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: accent)),
                if (lab.reviewedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Проверено: ${_labShortDate(lab.reviewedAt)}',
                    style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor),
                  ),
                ] else if (lab.isSubmittedForGrading && lab.submittedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Сдано: ${_labShortDate(lab.submittedAt)}',
                    style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor),
                  ),
                ],
                if (lab.score != null) ...[
                  const SizedBox(height: 6),
                  Text('Оценка: ${lab.score}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabSectionCard extends StatelessWidget {
  const _LabSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        child,
      ],
    );
  }
}

class _LabDateMeta extends StatelessWidget {
  const _LabDateMeta({required this.lab});

  final LabWork lab;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (lab.deadline != null) {
      rows.add(_dateRow(PhosphorIconsRegular.calendarBlank, 'Крайний срок', _labShortDate(lab.deadline)));
    }
    if (lab.submittedAt != null) {
      rows.add(_dateRow(PhosphorIconsRegular.paperPlaneTilt, 'Сдано', _labShortDate(lab.submittedAt)));
    }
    if (lab.reviewedAt != null) {
      rows.add(_dateRow(PhosphorIconsRegular.checkCircle, 'Проверено', _labShortDate(lab.reviewedAt)));
    }
    if (rows.isEmpty) {
      rows.add(_dateRow(PhosphorIconsRegular.calendar, 'Дата', _labShortDate(lab.updatedAt)));
    }
    return Column(children: rows);
  }

  Widget _dateRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppConstants.secondaryColor),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _LabStatusBadge extends StatelessWidget {
  const _LabStatusBadge({required this.lab, this.compact = false});

  final LabWork lab;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _labStatusColor(lab);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 5 : 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Text(
            lab.displayStatusLabel,
            style: TextStyle(color: accent, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w800),
          ),
        ),
        if (lab.reviewedAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Проверено: ${_labShortDate(lab.reviewedAt)}',
            style: TextStyle(fontSize: 11, color: AppConstants.secondaryColor),
          ),
        ],
      ],
    );
  }
}

class _LabDetailsPanel extends StatelessWidget {
  const _LabDetailsPanel({required this.lab});

  final LabWork lab;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _infoRow('Номер попытки', '1 из 5'),
          _infoRow('Состояние ответа', lab.submissionStatusLabel, highlight: lab.submissionStatusPositive),
          _infoRow(
            'Состояние оценивания',
            lab.gradingStatusLabel,
            subtitle: lab.reviewedAt != null ? 'Проверено: ${_labLongDateTime(lab.reviewedAt)}' : null,
          ),
          if (lab.deadline != null) _infoRow('Крайний срок', _labLongDateTime(lab.deadline)),
          if (lab.submittedAt != null) _infoRow('Дата отправки', _labLongDateTime(lab.submittedAt)),
          if (lab.reviewedAt != null) _infoRow('Дата проверки', _labLongDateTime(lab.reviewedAt)),
          _infoRow('Последнее изменение', _labLongDateTime(lab.updatedAt)),
          if (lab.submissionFileNames.isNotEmpty)
            _infoRow('Файлы ответа', lab.submissionFileNames.join('\n'), multiline: true),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool highlight = false, String? subtitle, bool multiline = false}) {
    final bg = highlight ? const Color(0xFFE8F5E9) : AppConstants.surfaceWhite;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: AppConstants.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, height: multiline ? 1.45 : 1.2),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)),
          ],
        ],
      ),
    );
  }
}

class _FeedbackBlock extends StatelessWidget {
  const _FeedbackBlock({required this.lab});

  final LabWork lab;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final feedback = lab.teacherComment?.trim();
    if (feedback != null && feedback.isNotEmpty) {
      items.add(_feedbackRow('Отзыв в виде комментария', feedback));
    }
    for (final c in lab.teacherCommentsOnly) {
      if (feedback != null && c.text.trim() == feedback) continue;
      items.add(_feedbackRow('Комментарий преподавателя', c.text, at: c.timestamp));
    }
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.borderSubtle),
        ),
        child: Text('Преподаватель пока не оставил отзыв', style: TextStyle(color: AppConstants.secondaryColor)),
      );
    }
    return Column(
      children: items.map((w) => Padding(padding: const EdgeInsets.only(bottom: 8), child: w)).toList(),
    );
  }

  Widget _feedbackRow(String label, String text, {DateTime? at}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        border: Border.all(color: AppConstants.borderSubtle),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600)),
          if (at != null) ...[
            const SizedBox(height: 6),
            Text(
              _labLongDateTime(at),
              style: TextStyle(fontSize: 11, color: AppConstants.secondaryColor),
            ),
          ],
        ],
      ),
    );
  }
}

class LabSubmissionScreen extends StatefulWidget {
  const LabSubmissionScreen({super.key, required this.labId});

  final String labId;

  @override
  State<LabSubmissionScreen> createState() => _LabSubmissionScreenState();
}

class _LabSubmissionScreenState extends State<LabSubmissionScreen> {
  final _pending = <PlatformFile>[];
  bool _saving = false;

  Future<void> _addFiles() async {
    final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      for (final file in result.files) {
        if (file.name.isEmpty) continue;
        if (_pending.length >= 20) break;
        if (!_pending.any((p) => p.name == file.name)) {
          _pending.add(file);
        }
      }
    });
  }

  void _removeFile(int index) => setState(() => _pending.removeAt(index));

  Future<void> _save() async {
    if (_pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один файл перед сохранением')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<LabsProvider>().saveSubmission(
            widget.labId,
            files: [
              for (final f in _pending)
                (filePath: f.path, fileBytes: f.bytes, fileName: f.name),
            ],
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ответ сохранён и отправлен на проверку')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить ответ'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<LabsProvider>();
    final lab = prov.labs.firstWhere((l) => l.id == widget.labId, orElse: () => prov.labs.first);

    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      appBar: AppBar(title: const Text('Добавить ответ на задание')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(lab.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 16),
                Text('Ответ в виде файла', style: TextStyle(fontWeight: FontWeight.w700, color: AppConstants.secondaryColor)),
                const SizedBox(height: 4),
                Text(
                  'Максимальный размер новых файлов: 75 Мбайт, максимум прикреплённых файлов: 20',
                  style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, height: 1.35),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppConstants.borderSubtle),
                    borderRadius: BorderRadius.circular(8),
                    color: AppConstants.surfaceMuted,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Добавить файл',
                            onPressed: _addFiles,
                            icon: const Icon(PhosphorIconsRegular.filePlus),
                          ),
                          const Spacer(),
                          Text('${_pending.length} / 20', style: TextStyle(color: AppConstants.secondaryColor)),
                        ],
                      ),
                      if (_pending.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Файлы не выбраны',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppConstants.secondaryColor),
                          ),
                        )
                      else
                        for (var i = 0; i < _pending.length; i++)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _pending[i].name.toLowerCase().endsWith('.pdf')
                                  ? PhosphorIconsRegular.filePdf
                                  : PhosphorIconsRegular.file,
                            ),
                            title: Text(_pending[i].name),
                            trailing: IconButton(
                              icon: const Icon(PhosphorIconsRegular.trash, size: 20),
                              onPressed: () => _removeFile(i),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ответ будет отправлен только после нажатия «Сохранить».',
                  style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, height: 1.35),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
