import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/providers/events_provider.dart';
import '../../core/providers/exams_provider.dart';
import '../../core/providers/grades_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../data/models/event.dart';
import '../../data/models/grade.dart';
import '../../data/models/exam.dart';
import 'sheet_handle.dart';

class StatsSwitcher extends StatefulWidget {
  const StatsSwitcher({super.key});

  @override
  State<StatsSwitcher> createState() => _StatsSwitcherState();
}

class _StatsSwitcherState extends State<StatsSwitcher> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Оценки', 'Сессия', 'Статистика'];

  void _showGradesDetails(BuildContext context, GradesProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
      ),
      builder: (context) => _buildGradesDetails(provider),
    );
  }

  void _showSessionDetails(BuildContext context, ExamsProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
      ),
      builder: (context) => _buildSessionDetails(provider),
    );
  }

  void _showStatsDetails(BuildContext context,
      GradesProvider gradesProvider, EventsProvider eventsProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
      ),
      builder: (context) => _buildStatsDetails(gradesProvider, eventsProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradesProvider = context.watch<GradesProvider>();
    final examsProvider = context.watch<ExamsProvider>();
    final eventsProvider = context.watch<EventsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _tabs.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = index;
                  });
                },
                child: Container(
                  constraints: BoxConstraints(minWidth: 80),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _selectedTab == index ? AppConstants.blockBlack : AppConstants.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedTab == index ? AppConstants.blockBlack : const Color(0xFFE8E8E6),
                    ),
                  ),
                  child: Text(
                    _tabs[index],
                    style: TextStyle(
                      color: _selectedTab == index ? AppConstants.onBlock : AppConstants.blockBlack,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 16),

        Container(
          height: 150,
          child: _buildContent(gradesProvider, examsProvider, eventsProvider),
        ),
      ],
    );
  }

  Widget _buildContent(
      GradesProvider gradesProvider,
      ExamsProvider examsProvider,
      EventsProvider eventsProvider,
      ) {
    switch (_selectedTab) {
      case 0:
        return _buildGradesTab(gradesProvider);
      case 1:
        return _buildSessionTab(examsProvider);
      case 2:
        return _buildStatsTab(gradesProvider, eventsProvider);
      default:
        return Container();
    }
  }

  Widget _buildGradesTab(GradesProvider provider) {
    final grades = provider.grades;
    final averageGrade = provider.averageGrade;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showGradesDetails(context, provider),
            child: _buildSquareCard(
              icon: PhosphorIconsRegular.chartLineUp,
              title: 'Средний балл',
              value: averageGrade.toStringAsFixed(2),
              subtitle: 'За все время',
              color: AppConstants.surfaceMuted,
              textColor: AppConstants.blockBlack,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _showGradesDetails(context, provider),
            child: _buildSquareCard(
              icon: PhosphorIconsRegular.books,
              title: 'Всего предметов',
              value: grades.length.toString(),
              subtitle: 'Всего',
              color: AppConstants.surfaceMuted,
              textColor: AppConstants.blockBlack,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionTab(ExamsProvider provider) {
    final upcomingExams = provider.upcomingExams;
    final completedExams = provider.completedExams;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showSessionDetails(context, provider),
            child: _buildSquareCard(
              icon: PhosphorIconsRegular.calendarBlank,
              title: 'Предстоящие',
              value: upcomingExams.length.toString(),
              subtitle: 'экзаменов',
              color: AppConstants.surfaceMuted,
              textColor: AppConstants.blockBlack,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _showSessionDetails(context, provider),
            child: _buildSquareCard(
              icon: PhosphorIconsRegular.checkCircle,
              title: 'Сдано',
              value: completedExams.length.toString(),
              subtitle: 'экзаменов',
              color: AppConstants.surfaceMuted,
              textColor: AppConstants.blockBlack,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsTab(GradesProvider gradesProvider, EventsProvider eventsProvider) {
    final grades = gradesProvider.grades;
    final pastEvents = eventsProvider.pastEvents;

    final labs = grades.where((g) => g.type.toLowerCase().contains('лабораторная')).toList();
    final passedLabs = labs.where((l) => l.value >= 3).length;
    final totalEventsPoints = pastEvents.fold(0, (sum, event) => sum + event.points);

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showStatsDetails(context, gradesProvider, eventsProvider),
            child: _buildSquareCard(
              icon: PhosphorIconsRegular.flask,
              title: 'Лабораторные',
              value: '$passedLabs/${labs.length}',
              subtitle: 'сдано/всего',
              color: AppConstants.surfaceMuted,
              textColor: AppConstants.blockBlack,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _showStatsDetails(context, gradesProvider, eventsProvider),
            child: _buildSquareCard(
              icon: PhosphorIconsRegular.bellRinging,
              title: 'Уведомления',
              value: totalEventsPoints.toString(),
              subtitle: 'баллы',
              color: AppConstants.surfaceMuted,
              textColor: AppConstants.blockBlack,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSquareCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      constraints: BoxConstraints(
        minHeight: 150,
        maxHeight: 150,
      ),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E6)),
        boxShadow: [
          BoxShadow(
            color: AppConstants.blockBlack.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: textColor,
              size: 20,
            ),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppConstants.blockBlack,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGradesDetails(GradesProvider provider) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppConstants.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              const SizedBox(height: 8),
              const SheetGrabHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Сведения об успеваемости',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.blockBlack),
                          ),
                          const SizedBox(height: 6),
                          Consumer<StudentProvider>(
                            builder: (context, sp, _) {
                              final spec = sp.student?.specialty ?? '—';
                              return Text(
                                'Специальность: $spec',
                                style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor, height: 1.35),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppConstants.borderSubtle),
                      ),
                      child: Text(
                        'Средний\n${provider.averageGrade.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.blockBlack,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.grades.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(PhosphorIconsRegular.chartBar, size: 56, color: AppConstants.borderSubtle),
                      const SizedBox(height: 16),
                      Text('Нет данных об оценках', style: TextStyle(color: AppConstants.secondaryColor)),
                    ],
                  ),
                )
              else
                _GradesPedagogyTable(grades: provider.grades),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionDetails(ExamsProvider provider) {
    final upcomingExams = provider.upcomingExams;
    final completedExams = provider.completedExams;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppConstants.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppConstants.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Сессия',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        _buildExamBadge('Осталось', upcomingExams.length, AppConstants.blockBlack),
                        SizedBox(width: 8),
                        _buildExamBadge('Сдано', completedExams.length, AppConstants.secondaryColor),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  children: [
                    if (upcomingExams.isNotEmpty) ...[
                      Text(
                        'Предстоящие экзамены',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...upcomingExams.map((exam) => _buildDetailedExamItem(exam, false)).toList(),
                      SizedBox(height: 20),
                    ],

                    if (completedExams.isNotEmpty) ...[
                      Text(
                        'Сданные экзамены',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...completedExams.map((exam) => _buildDetailedExamItem(exam, true)).toList(),
                      SizedBox(height: 20),
                    ],

                    if (upcomingExams.isEmpty && completedExams.isEmpty) ...[
                      Center(
                        child: Column(
                          children: [
                            Icon(PhosphorIconsRegular.clipboardText, size: 56, color: Colors.grey[300]),
                            SizedBox(height: 16),
                            Text(
                              'Нет данных о сессии',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailedExamItem(Exam exam, bool isCompleted) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? AppConstants.surfaceMuted : AppConstants.borderSubtle,
          width: 2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted ? AppConstants.blockBlack : AppConstants.secondaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              isCompleted ? PhosphorIconsRegular.check : PhosphorIconsRegular.clock,
              color: AppConstants.surfaceWhite,
              size: 20,
            ),
          ),

          SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        exam.subject,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isCompleted && exam.grade != null)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getGradeColor(exam.grade!),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exam.grade!.toString(),
                          style: TextStyle(
                            color: AppConstants.surfaceWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(PhosphorIconsRegular.user, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        exam.teacher,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(PhosphorIconsRegular.calendarBlank, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      exam.date,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(PhosphorIconsRegular.clock, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      exam.time,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(PhosphorIconsRegular.mapPin, size: 14, color: Colors.grey[500]),
                    SizedBox(width: 4),
                    Text(
                      exam.classroom,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsDetails(GradesProvider gradesProvider, EventsProvider eventsProvider) {
    final grades = gradesProvider.grades;
    final pastEvents = eventsProvider.pastEvents;

    final labs = grades.where((g) => g.type.toLowerCase().contains('лабораторная')).toList();
    final passedLabs = labs.where((l) => l.value >= 3).length;
    final failedLabs = labs.where((l) => l.value < 3).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppConstants.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppConstants.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Статистика работ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.blockBlack,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${passedLabs}/${labs.length} сдано',
                        style: TextStyle(
                          color: AppConstants.surfaceWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(16),
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Лабораторные работы',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 12),

                          if (labs.isNotEmpty) ...[
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Прогресс'),
                                      Text('$passedLabs/${labs.length}'),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: labs.isNotEmpty ? passedLabs / labs.length : 0,
                                    backgroundColor: AppConstants.borderSubtle,
                                    color: AppConstants.blockBlack,
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),

                            ...labs.map((lab) => _buildLabItem(lab)).toList(),
                          ] else ...[ Center(
                            child: Container(
                              padding: EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(PhosphorIconsRegular.flask, size: 48, color: Colors.grey[300]),
                                  SizedBox(height: 12),
                                  Text(
                                    'Нет данных о лабораторных',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),

                    if (failedLabs.isNotEmpty) ...[
                      Container(
                        margin: EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Требуют пересдачи',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 12),
                            ...failedLabs.map((lab) => _buildFailedLabItem(lab)).toList(),
                          ],
                        ),
                      ),
                    ],

                    if (pastEvents.isNotEmpty) ...[
                      Container(
                        margin: EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Бонусные баллы',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppConstants.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Всего накоплено',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${pastEvents.fold(0, (sum, event) => sum + event.points)} баллов',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppConstants.blockBlack,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  ...pastEvents.take(3).map((event) => _buildEventItem(event)).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabItem(Grade lab) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: lab.value >= 3 ? AppConstants.surfaceMuted : AppConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(
              lab.value >= 3 ? PhosphorIconsRegular.check : PhosphorIconsRegular.x,
              color: lab.value >= 3 ? AppConstants.blockBlack : AppConstants.blockBlack,
              size: 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lab.subject,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Лабораторная работа • ${lab.teacher}',
                  style: TextStyle(
                    color: AppConstants.secondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: lab.value >= 3 ? AppConstants.blockBlack : AppConstants.blockBlack,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              lab.value >= 3 ? 'Сдано' : 'Не сдано',
              style: TextStyle(
                color: AppConstants.surfaceWhite,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedLabItem(Grade lab) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.warning, color: Colors.red, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lab.subject,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  'Лабораторная работа • ${lab.teacher}',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Оценка: ${lab.value}',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(Event event) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppConstants.surfaceMuted,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Icon(PhosphorIconsRegular.star, color: AppConstants.blockBlack, size: 12),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 8),
          Text(
            '+${event.points}',
            style: const TextStyle(
              color: AppConstants.blockBlack,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamBadge(String text, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Text(
            '$text: $count',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGradeColor(int grade) {
    if (grade >= 4) return AppConstants.blockBlack;
    if (grade == 3) return const Color(0xFF5C5C5C);
    return const Color(0xFF8E8E8E);
  }
}

class _GradesPedagogyTable extends StatefulWidget {
  const _GradesPedagogyTable({required this.grades});

  final List<Grade> grades;

  @override
  State<_GradesPedagogyTable> createState() => _GradesPedagogyTableState();
}

class _GradesPedagogyTableState extends State<_GradesPedagogyTable> {
  late int _semester;

  @override
  void initState() {
    super.initState();
    final keys = _groupedKeys();
    _semester = keys.isNotEmpty ? keys.first : 1;
  }

  @override
  void didUpdateWidget(covariant _GradesPedagogyTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grades != widget.grades) {
      final keys = _groupedKeys();
      if (keys.isNotEmpty && !keys.contains(_semester)) {
        _semester = keys.first;
      }
    }
  }

  static int _semesterOf(Grade g) {
    if (g.semester != null) return g.semester!.clamp(1, 8);
    final y = g.date.year;
    final m = g.date.month;
    if (m >= 9) {
      return ((y - 2022) * 2 + 1).clamp(1, 8);
    }
    return ((y - 2022) * 2).clamp(1, 8);
  }

  Map<int, List<Grade>> _group() {
    final m = <int, List<Grade>>{};
    for (final g in widget.grades) {
      final s = _semesterOf(g);
      m.putIfAbsent(s, () => []).add(g);
    }
    return m;
  }

  List<int> _groupedKeys() {
    final k = _group().keys.toList()..sort();
    return k;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _group();
    final semesters = grouped.keys.toList()..sort();
    if (semesters.isEmpty) return const SizedBox.shrink();
    if (!semesters.contains(_semester)) {
      _semester = semesters.first;
    }
    final list = List<Grade>.from(grouped[_semester] ?? [])..sort((a, b) => a.date.compareTo(b.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: semesters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = semesters[i];
              final sel = _semester == s;
              return FilterChip(
                selected: sel,
                label: Text('$s семестр'),
                onSelected: (_) => setState(() => _semester = s),
                selectedColor: AppConstants.blockBlack,
                checkmarkColor: AppConstants.surfaceWhite,
                labelStyle: TextStyle(
                  color: sel ? AppConstants.surfaceWhite : AppConstants.blockBlack,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                side: BorderSide(color: sel ? AppConstants.blockBlack : AppConstants.borderSubtle),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            children: [
              for (final g in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConstants.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                g.subject,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.25),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              g.displayGrade,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: AppConstants.blockBlack,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${g.type} · ${g.zet != null ? '${g.zet} з.е.' : '—'} · ${g.hours != null ? '${g.hours} ч.' : '—'} · ${DateFormat('dd.MM.yy').format(g.date)}',
                          style: TextStyle(fontSize: 11, color: AppConstants.secondaryColor, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}