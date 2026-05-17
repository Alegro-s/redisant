import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/providers/main_nav_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../data/models/student.dart';
import '../widgets/app_logout.dart';
import '../widgets/app_settings_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final student = studentProvider.student;

    if (student == null) {
      return Scaffold(
        backgroundColor: AppConstants.surfaceWhite,
        appBar: AppBar(title: const Text('Профиль')),
        body: const Center(child: CircularProgressIndicator(color: AppConstants.blockBlack)),
      );
    }

    final tiles = _profileTiles(student);

    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      body: RefreshIndicator(
        color: AppConstants.terracotta,
        onRefresh: () => studentProvider.loadStudentData(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _ProfileHeader(student: student)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => showAppSettingsSheet(context),
                      icon: const Icon(PhosphorIconsRegular.gear, color: AppConstants.blockBlack),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => studentProvider.loadStudentData(),
                      icon: const Icon(PhosphorIconsRegular.arrowsClockwise, color: AppConstants.blockBlack),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PromoBanner(onTap: () => _openUrl(AppConstants.portalRegisterUrl)),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сервисы',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.secondaryColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ServiceChipsRow(
                      onSchedule: () => context.read<MainNavProvider>().setTab(1),
                      onShowcase: () => context.read<MainNavProvider>().setTab(2),
                      onHome: () => context.read<MainNavProvider>().setTab(0),
                      onSite: () => _openUrl(AppConstants.portalRegisterUrl),
                      onStudy: () => _openUrl(AppConstants.portalStudyUrl),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    title: const Text(
                      'Мои данные',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.blockBlack,
                      ),
                    ),
                    subtitle: Text(
                      'Контакты, зачётка, стипендия',
                      style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor),
                    ),
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          const gap = 12.0;
                          final w = (c.maxWidth - gap) / 2;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final t in tiles)
                                SizedBox(
                                  width: w,
                                  child: _FieldCard(label: t.$1, value: t.$2),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: OutlinedButton(
                  onPressed: () => showLogoutConfirmDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0x33B91C1C)),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Выйти из аккаунта', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<(String, String)> _profileTiles(Student student) {
  final info = student.additionalInfo;
  return [
    ('ФИО', student.fullName),
    ('Группа', student.group),
    ('Институт', student.faculty),
    ('Специальность', student.specialty),
    ('Курс', '${student.course}'),
    ('Почта', student.email),
    ('Телефон', student.phone),
    ('Адрес', student.address),
    if (info['recordBook'] != null) ('Зачётная книжка', info['recordBook'].toString()),
    if (info['trainingLevel'] != null) ('Уровень подготовки', info['trainingLevel'].toString()),
    if (info['profile'] != null) ('Профиль', info['profile'].toString()),
    if (info['studentStatus'] != null) ('Статус', info['studentStatus'].toString()),
    if (info['birthDate'] != null) ('Дата рождения', info['birthDate'].toString()),
    (
      'Поступление',
      '${student.admissionDate.day.toString().padLeft(2, '0')}.${student.admissionDate.month.toString().padLeft(2, '0')}.${student.admissionDate.year}',
    ),
    (
      'Выпуск',
      '${student.graduationDate.day.toString().padLeft(2, '0')}.${student.graduationDate.month.toString().padLeft(2, '0')}.${student.graduationDate.year}',
    ),
    if (info['scholarship'] != null) ('Стипендия', '${info['scholarship']} ₽'),
    if (info['dormitory'] != null) ('Общежитие', info['dormitory'].toString()),
    if (info['averageGrade'] != null) ('Средний балл', info['averageGrade'].toString()),
  ];
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 124,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppConstants.blockBlack,
                      AppConstants.blockBlackElevated,
                      Color(0xFF2C2C2C),
                    ],
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: Icon(
                      PhosphorIconsRegular.graduationCap,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -44),
          child: Column(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppConstants.surfaceWhite,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppConstants.surfaceMuted,
                  backgroundImage: student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
                  child: student.avatarUrl == null
                      ? Icon(PhosphorIconsRegular.user, size: 44, color: AppConstants.secondaryColor)
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  student.fullName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppConstants.blockBlack,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${student.group} · курс ${student.course}',
                style: TextStyle(fontSize: 14, color: AppConstants.secondaryColor),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  student.specialty,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.35, color: AppConstants.secondaryColor),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppConstants.terracottaMuted,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppConstants.terracotta, width: 4),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Стипендии и сервисы',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppConstants.terracottaDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Новости университета, льготы и документы на портале',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.blockBlack,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, color: AppConstants.terracottaDark, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceChipsRow extends StatelessWidget {
  const _ServiceChipsRow({
    required this.onSchedule,
    required this.onShowcase,
    required this.onHome,
    required this.onSite,
    required this.onStudy,
  });

  final VoidCallback onSchedule;
  final VoidCallback onShowcase;
  final VoidCallback onHome;
  final VoidCallback onSite;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (PhosphorIconsRegular.calendarBlank, 'Расписание', onSchedule),
      (PhosphorIconsRegular.squaresFour, 'Витрина', onShowcase),
      (PhosphorIconsRegular.house, 'Главная', onHome),
      (PhosphorIconsRegular.globe, 'Сайт', onSite),
      (PhosphorIconsRegular.graduationCap, 'Обучение', onStudy),
    ];
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          return SizedBox(
            width: 76,
            child: InkWell(
              onTap: it.$3,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.borderSubtle),
                    ),
                    child: Icon(it.$1, color: AppConstants.terracottaDark, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    it.$2,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceWhite,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppConstants.secondaryColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppConstants.blockBlack,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
