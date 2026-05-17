import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/providers/exams_provider.dart';
import '../../core/providers/grades_provider.dart';
import '../../core/providers/labs_provider.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/providers/student_provider.dart';
import '../widgets/app_settings_sheet.dart';
import '../widgets/profile_card.dart';
import '../widgets/schedule_card.dart';
import '../widgets/stats_switcher.dart';
import 'labs_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      appBar: AppBar(title: const Text('Главная')),
      body: RefreshIndicator(
        color: AppConstants.blockBlack,
        onRefresh: () async {
          await Future.wait([
            context.read<StudentProvider>().loadStudentData(),
            context.read<ScheduleProvider>().loadSchedule(),
            context.read<GradesProvider>().loadGrades(),
            context.read<ExamsProvider>().loadExams(),
            context.read<LabsProvider>().loadLabs(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileCard(
                onSettingsPressed: () => showAppSettingsSheet(context),
                onRefreshPressed: () async {
                  await Future.wait([
                    context.read<StudentProvider>().loadStudentData(),
                    context.read<ScheduleProvider>().loadSchedule(),
                    context.read<GradesProvider>().loadGrades(),
                    context.read<ExamsProvider>().loadExams(),
                    context.read<LabsProvider>().loadLabs(),
                  ]);
                },
              ),
              const SizedBox(height: 20),
              const StatsSwitcher(),
              const SizedBox(height: 20),
              const _HomeMoodleLabsCard(),
              const SizedBox(height: 22),
              Text(
                'Расписание на сегодня',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 14),
              const ScheduleList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMoodleLabsCard extends StatelessWidget {
  const _HomeMoodleLabsCard();

  @override
  Widget build(BuildContext context) {
    final labs = context.watch<LabsProvider>();
    final preview = labs.labs.take(3).toList();

    return Material(
      color: AppConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const LabsScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Лабораторные (Moodle)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppConstants.blockBlack),
                    ),
                  ),
                  if (labs.isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.blockBlack),
                    )
                  else
                    Icon(Icons.chevron_right, color: AppConstants.secondaryColor),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Статусы сдачи и комментарии с портала',
                style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor, height: 1.3),
              ),
              if (labs.error != null) ...[
                const SizedBox(height: 8),
                Text(labs.error!, style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
              ] else if (preview.isEmpty && !labs.isLoading) ...[
                const SizedBox(height: 8),
                Text('Нет данных — откройте экран целиком', style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)),
              ] else ...[
                const SizedBox(height: 12),
                for (final l in preview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l.course} · ${l.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l.status,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppConstants.terracottaDark),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
