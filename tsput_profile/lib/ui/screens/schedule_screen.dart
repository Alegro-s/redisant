import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/providers/schedule_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../data/models/schedule.dart';
import '../widgets/schedule_detail_sheet.dart';
import '../widgets/sheet_handle.dart';
import '../widgets/week_schedule_plan_table.dart';

String _sentenceCaseRu(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

String _facultyShort(String faculty) {
  if (faculty.length <= 22) return faculty;
  return '${faculty.substring(0, 20)}…';
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  DateTime _selectedDay = DateTime.now();
  String? _typeFilter;
  bool _weekPlanMode = false;
  late final TabController _weekTabController;

  @override
  void initState() {
    super.initState();
    final mon = _dateOnly(_selectedDay).subtract(Duration(days: _dateOnly(_selectedDay).weekday - DateTime.monday));
    final idx = _dateOnly(_selectedDay).difference(mon).inDays.clamp(0, 6);
    _weekTabController = TabController(length: 7, vsync: this, initialIndex: idx);
    _weekTabController.addListener(_onWeekTabChanged);
  }

  void _onWeekTabChanged() {
    if (!mounted) return;
    if (_weekTabController.indexIsChanging) return;
    final mon = _weekMonday;
    setState(() {
      _selectedDay = mon.add(Duration(days: _weekTabController.index));
    });
  }

  @override
  void dispose() {
    _weekTabController.removeListener(_onWeekTabChanged);
    _weekTabController.dispose();
    super.dispose();
  }

  void _syncTabToSelectedDay() {
    final mon = _weekMonday;
    final idx = _dateOnly(_selectedDay).difference(_dateOnly(mon)).inDays.clamp(0, 6);
    if (_weekTabController.index != idx) {
      _weekTabController.animateTo(idx);
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _weekMonday {
    final x = _dateOnly(_selectedDay);
    return x.subtract(Duration(days: x.weekday - DateTime.monday));
  }

  List<Schedule> _applyType(List<Schedule> list) {
    if (_typeFilter == null) return list;
    return list.where((s) => s.type.toLowerCase() == _typeFilter!.toLowerCase()).toList();
  }

  List<Schedule> _eventsForDay(DateTime day, List<Schedule> all) {
    final key = _dateOnly(day);
    final filtered = all.where((s) => _dateOnly(s.startTime) == key).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return filtered;
  }

  void _shiftWeek(int delta) {
    setState(() {
      _selectedDay = _weekMonday.add(Duration(days: 7 * delta));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTabToSelectedDay();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2023),
      lastDate: DateTime(2028),
      locale: const Locale('ru', 'RU'),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
      _syncTabToSelectedDay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      appBar: AppBar(
        title: const Text('Расписание'),
        actions: [
          IconButton(
            tooltip: _weekPlanMode ? 'Список на день' : 'План недели (табель)',
            icon: Icon(_weekPlanMode ? PhosphorIconsRegular.listBullets : PhosphorIconsRegular.table),
            onPressed: () => setState(() => _weekPlanMode = !_weekPlanMode),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.faders),
            onPressed: () => _showTypeFilterSheet(context),
          ),
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => context.read<ScheduleProvider>().loadSchedule(),
          ),
        ],
      ),
      body: Consumer2<ScheduleProvider, StudentProvider>(
        builder: (context, scheduleProv, studentProv, _) {
          if (scheduleProv.isLoading && scheduleProv.schedule.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppConstants.blockBlack));
          }
          final all = _applyType(scheduleProv.schedule);
          final student = studentProv.student;
          final dayEvents = _eventsForDay(_selectedDay, all);
          final mon = _weekMonday;

          if (_weekPlanMode) {
            final headerTitle = student != null ? _facultyShort(student.faculty) : 'ТГПУ';
            final groupLine = student?.group ?? '—';
            return RefreshIndicator(
              color: AppConstants.blockBlack,
              onRefresh: () => scheduleProv.loadSchedule(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (student != null)
                            Text(
                              '${student.group} · ${student.faculty}',
                              style: TextStyle(fontSize: 13, height: 1.35, color: AppConstants.secondaryColor),
                            )
                          else
                            Text('Загрузка профиля…', style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _shiftWeek(-1),
                                icon: const Icon(PhosphorIconsRegular.caretLeft),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickDate,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Column(
                                      children: [
                                        Text(
                                          _sentenceCaseRu(DateFormat('LLLL yyyy', 'ru_RU').format(mon)),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                        ),
                                        Text(
                                          '${DateFormat('dd.MM', 'ru_RU').format(mon)} — ${DateFormat('dd.MM', 'ru_RU').format(mon.add(const Duration(days: 6)))}',
                                          style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _shiftWeek(1),
                                icon: const Icon(PhosphorIconsRegular.caretRight),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: Column(
                      children: [
                        Material(
                          color: AppConstants.surfaceWhite,
                          child: TabBar(
                            controller: _weekTabController,
                            isScrollable: true,
                            labelColor: AppConstants.blockBlack,
                            indicatorColor: AppConstants.blockBlack,
                            tabs: [
                              for (int i = 0; i < 7; i++)
                                Tab(
                                  child: _WeekTabLabel(day: mon.add(Duration(days: i))),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _weekTabController,
                            children: [
                              for (int i = 0; i < 7; i++)
                                WeekSchedulePlanDayTable(
                                  day: mon.add(Duration(days: i)),
                                  items: _eventsForDay(mon.add(Duration(days: i)), all),
                                  headerTitle: headerTitle,
                                  groupLine: groupLine,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppConstants.blockBlack,
            onRefresh: () => scheduleProv.loadSchedule(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (student != null)
                  Text(
                    '${student.group} · ${student.faculty}',
                    style: TextStyle(fontSize: 13, height: 1.35, color: AppConstants.secondaryColor),
                  )
                else
                  Text('Загрузка профиля…', style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _shiftWeek(-1),
                      icon: const Icon(PhosphorIconsRegular.caretLeft),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              Text(
                                _sentenceCaseRu(DateFormat('LLLL yyyy', 'ru_RU').format(mon)),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              Text(
                                '${DateFormat('dd.MM', 'ru_RU').format(mon)} — ${DateFormat('dd.MM', 'ru_RU').format(mon.add(const Duration(days: 6)))}',
                                style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _shiftWeek(1),
                      icon: const Icon(PhosphorIconsRegular.caretRight),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 7,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final d = mon.add(Duration(days: i));
                      final sel = _dateOnly(d) == _dateOnly(_selectedDay);
                      final today = _dateOnly(d) == _dateOnly(DateTime.now());
                      var shortWd = DateFormat('EEE', 'ru_RU').format(d);
                      if (shortWd.endsWith('.')) {
                        shortWd = shortWd.substring(0, shortWd.length - 1);
                      }
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDay = d);
                          if (_weekTabController.index != i) {
                            _weekTabController.animateTo(i);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          decoration: BoxDecoration(
                            color: sel ? AppConstants.blockBlack : AppConstants.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: today ? AppConstants.blockBlack : AppConstants.borderSubtle,
                              width: today ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                shortWd,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: sel ? AppConstants.surfaceWhite : AppConstants.secondaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${d.day}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: sel ? AppConstants.surfaceWhite : AppConstants.blockBlack,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _sentenceCaseRu(DateFormat('EEEE, d MMMM', 'ru_RU').format(_selectedDay)),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppConstants.blockBlack),
                ),
                const SizedBox(height: 12),
                if (dayEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Text(
                        'Нет занятий в этот день',
                        style: TextStyle(color: AppConstants.secondaryColor, fontSize: 15),
                      ),
                    ),
                  )
                else
                  ...dayEvents.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ScheduleEventCard(
                        e: e,
                        onTap: () => showScheduleDetailSheet(context, e),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTypeFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        void pick(String? type) {
          setState(() => _typeFilter = type);
          Navigator.pop(ctx);
        }

        return Container(
          decoration: const BoxDecoration(
            color: AppConstants.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetGrabHandle(),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text(
                      'Тип занятия',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  ListTile(
                    title: const Text('Все типы'),
                    trailing: _typeFilter == null
                        ? const Icon(PhosphorIconsRegular.check, color: AppConstants.blockBlack)
                        : null,
                    onTap: () => pick(null),
                  ),
                  ListTile(
                    title: const Text('Лекция'),
                    trailing: _typeFilter?.toLowerCase() == 'лекция'
                        ? const Icon(PhosphorIconsRegular.check, color: AppConstants.blockBlack)
                        : null,
                    onTap: () => pick('лекция'),
                  ),
                  ListTile(
                    title: const Text('Практика'),
                    trailing: _typeFilter?.toLowerCase() == 'практика'
                        ? const Icon(PhosphorIconsRegular.check, color: AppConstants.blockBlack)
                        : null,
                    onTap: () => pick('практика'),
                  ),
                  ListTile(
                    title: const Text('Лабораторная'),
                    trailing: _typeFilter?.toLowerCase() == 'лабораторная'
                        ? const Icon(PhosphorIconsRegular.check, color: AppConstants.blockBlack)
                        : null,
                    onTap: () => pick('лабораторная'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekTabLabel extends StatelessWidget {
  const _WeekTabLabel({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    var shortWd = DateFormat('EEE', 'ru_RU').format(day);
    if (shortWd.endsWith('.')) {
      shortWd = shortWd.substring(0, shortWd.length - 1);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(shortWd, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        Text(DateFormat('dd.MM').format(day), style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _ScheduleEventCard extends StatelessWidget {
  const _ScheduleEventCard({required this.e, required this.onTap});

  final Schedule e;
  final VoidCallback onTap;

  static String _typeRu(String type) {
    final t = type.toLowerCase();
    if (t.contains('лек')) return 'Лекция';
    if (t.contains('лаб')) return 'Лабораторная';
    if (t.contains('прак')) return 'Практика';
    return type;
  }

  @override
  Widget build(BuildContext context) {
    final time =
        '${DateFormat('HH:mm').format(e.startTime)} — ${DateFormat('HH:mm').format(e.endTime)}';
    return Material(
      color: AppConstants.surfaceWhite,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppConstants.blockBlack,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.subject,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_typeRu(e.type)} · ${e.classroom.isEmpty ? 'ауд. не указана' : e.classroom}',
                        style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, height: 1.3),
                      ),
                      if (e.teacher.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.teacher,
                          style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, height: 1.3),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(PhosphorIconsRegular.caretRight, color: AppConstants.borderSubtle, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
