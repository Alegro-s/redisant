import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../data/models/student.dart';
import '../../core/providers/main_nav_provider.dart';
import '../../core/providers/portfolio_provider.dart';
import '../../core/providers/student_provider.dart';
import '../../data/portfolio_pedagogy_sections.dart';
import '../widgets/portfolio_category_sheet.dart';
import 'labs_screen.dart';

String _loyaltyCardDigits(String seed) {
  var h = 2166136261;
  for (final u in seed.codeUnits) {
    h ^= u;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  final parts = <String>[];
  for (var i = 0; i < 4; i++) {
    final slice = (h >> (i * 8)) & 0xFFFF;
    parts.add(slice.toString().padLeft(4, '0'));
  }
  return parts.join(' ');
}

bool _emailsMatch(String? a, String? b) {
  if (a == null || b == null) return false;
  return a.trim().toLowerCase() == b.trim().toLowerCase();
}

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  final ScrollController _scroll = ScrollController();
  final PageController _heroPage = PageController();
  final GlobalKey _loyaltyKey = GlobalKey();
  final GlobalKey _portfolioKey = GlobalKey();
  String? _linkedEmail;
  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLoyaltyEmail();
      if (mounted) context.read<PortfolioProvider>().loadPortfolio();
    });
  }

  Future<void> _loadLoyaltyEmail() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _linkedEmail = p.getString(AppConstants.loyaltyLinkedEmailPrefKey));
  }

  Future<void> _saveLoyaltyEmail(String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(AppConstants.loyaltyLinkedEmailPrefKey, email.trim());
    if (mounted) setState(() => _linkedEmail = email.trim());
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  void _goTab(int index) => context.read<MainNavProvider>().setTab(index);

  void _openSearch() {
    showSearch<void>(
      context: context,
      delegate: _ShowcaseSearchDelegate(
        onSchedule: () => _goTab(1),
        onHome: () => _goTab(0),
        onOpenPortfolio: () => context.read<MainNavProvider>().goToShowcasePortfolio(),
        onScrollLoyalty: () => _scrollTo(_loyaltyKey),
        onServices: () => _openServicesSheet(context),
        onCertificates: () => _openCertificatesSheet(context),
        onLabs: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const LabsScreen()),
          );
        },
      ),
    );
  }

  void _openServicesSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Сервисы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.globe, color: AppConstants.blockBlack),
                  title: const Text('Сайт ТГПУ'),
                  subtitle: Text(AppConstants.portalRegisterUrl, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  onTap: () {
                    Navigator.pop(c);
                    _openUrl(AppConstants.portalRegisterUrl);
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.graduationCap, color: AppConstants.blockBlack),
                  title: const Text('Портал обучения'),
                  subtitle: Text(AppConstants.portalStudyUrl, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  onTap: () {
                    Navigator.pop(c);
                    _openUrl(AppConstants.portalStudyUrl);
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.calendarBlank, color: AppConstants.blockBlack),
                  title: const Text('Расписание'),
                  onTap: () {
                    Navigator.pop(c);
                    _goTab(1);
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.flask, color: AppConstants.blockBlack),
                  title: const Text('Лабораторные Moodle'),
                  subtitle: const Text('Статусы заданий'),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(builder: (_) => const LabsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.house, color: AppConstants.blockBlack),
                  title: const Text('Главная'),
                  onTap: () {
                    Navigator.pop(c);
                    _goTab(0);
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.user, color: AppConstants.blockBlack),
                  title: const Text('Профиль'),
                  onTap: () {
                    Navigator.pop(c);
                    _goTab(3);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCertificatesSheet(BuildContext ctx) {
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AppConstants.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Документы', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.fileText, color: AppConstants.blockBlack),
                  title: const Text('Справка об обучении'),
                  onTap: () {
                    Navigator.pop(c);
                    _openUrl(AppConstants.portalRegisterUrl);
                  },
                ),
                ListTile(
                  leading: Icon(PhosphorIconsRegular.scroll, color: AppConstants.blockBlack),
                  title: const Text('Транскрипт'),
                  onTap: () {
                    Navigator.pop(c);
                    _openUrl(AppConstants.portalStudyUrl);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _heroPage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<MainNavProvider>();
    if (nav.shouldScrollShowcasePortfolio) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<MainNavProvider>().clearShowcasePortfolioScroll();
        _scrollTo(_portfolioKey);
      });
    }

    return Scaffold(
      backgroundColor: AppConstants.surfaceWhite,
      body: RefreshIndicator(
        color: AppConstants.terracotta,
        onRefresh: () async {
          final studentProv = context.read<StudentProvider>();
          final portfolioProv = context.read<PortfolioProvider>();
          await studentProv.loadStudentData();
          if (!mounted) return;
          await portfolioProv.loadPortfolio();
          if (!mounted) return;
          await _loadLoyaltyEmail();
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeroAndOverlapSheet(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<(String, String, String, List<Color>)> get _heroSlides => [
        (
          'Стипендии',
          'Льготы и выплаты',
          'Матпомощь, категории и сроки',
          [const Color(0xFF3A2520), AppConstants.terracottaDark, AppConstants.terracotta],
        ),
        (
          'Университет',
          'ТГПУ рядом с вами',
          'Обучение, расписание, сервисы',
          [AppConstants.blockBlack, AppConstants.blockBlackElevated, const Color(0xFF2C2C2C)],
        ),
        (
          'Карьера',
          'Наука и проекты',
          'Практики, ВКР, мероприятия',
          [const Color(0xFF1E2D28), const Color(0xFF2A4038), const Color(0xFF355A4F)],
        ),
      ];

  Widget _buildHeroAndOverlapSheet(BuildContext context) {
    final slides = _heroSlides;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppConstants.appName,
                    style: const TextStyle(
                      color: AppConstants.blockBlack,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openSearch,
                  icon: const Icon(PhosphorIconsRegular.magnifyingGlass, color: AppConstants.blockBlack, size: 26),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 236,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _heroPage,
                    onPageChanged: (i) => setState(() => _heroIndex = i),
                    itemCount: slides.length,
                    itemBuilder: (context, i) {
                      final s = slides[i];
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: s.$4,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              right: -24,
                              bottom: -16,
                              child: Icon(
                                PhosphorIconsRegular.graduationCap,
                                size: 120,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(22, 28, 22, 40),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      s.$1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    s.$2,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      height: 1.15,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.$3,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 14,
                                      height: 1.35,
                                    ),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppConstants.blockBlack,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                    ),
                                    onPressed: () => _openUrl(AppConstants.portalRegisterUrl),
                                    child: const Text('Подробнее'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _heroIndex == i ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _heroIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -32),
          child: Material(
            color: AppConstants.surfaceWhite,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: AppConstants.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: _openSearch,
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  const SizedBox(width: 14),
                                  Icon(PhosphorIconsRegular.magnifyingGlass, color: Colors.grey[600], size: 22),
                                  const SizedBox(width: 10),
                                  Text('Поиск', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _openServicesSheet(context),
                        style: TextButton.styleFrom(foregroundColor: AppConstants.terracottaDark),
                        child: const Text('Сервисы'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBentoGrid(context),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: _loyaltyKey,
                    child: _buildLoyaltySection(context),
                  ),
                  const SizedBox(height: 16),
                  _buildPastelShortcutRow(context),
                  const SizedBox(height: 20),
                  KeyedSubtree(
                    key: _portfolioKey,
                    child: _buildPortfolioSection(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoGrid(BuildContext context) {
    const h = 148.0;
    return SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Material(
              color: AppConstants.terracottaMuted,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.read<MainNavProvider>().goToShowcasePortfolio(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      right: -6,
                      bottom: -6,
                      child: Icon(
                        PhosphorIconsRegular.student,
                        size: 88,
                        color: AppConstants.terracotta.withValues(alpha: 0.22),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Учёба',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.terracottaDark,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Text(
                            'Портфолио',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppConstants.blockBlack,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Разделы плана и документы',
                            style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 9,
            child: Column(
              children: [
                Expanded(
                  child: _bentoSmallCard(
                    title: 'Карта',
                    subtitle: 'Лояльность',
                    icon: PhosphorIconsRegular.identificationCard,
                    bg: const Color(0xFFE8EDF5),
                    iconColor: const Color(0xFF4A6FA5),
                    onTap: () => _scrollTo(_loyaltyKey),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _bentoSmallCard(
                    title: 'Документы',
                    subtitle: 'Справки',
                    icon: PhosphorIconsRegular.fileText,
                    bg: const Color(0xFFE6F4EF),
                    iconColor: const Color(0xFF2E7D5A),
                    onTap: () => _openCertificatesSheet(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bentoSmallCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppConstants.blockBlack),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: AppConstants.secondaryColor),
                    ),
                  ],
                ),
              ),
              Icon(icon, color: iconColor, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoyaltySection(BuildContext context) {
    final student = context.watch<StudentProvider>().student;
    final profileEmail = student?.email.trim() ?? '';
    final linked = _emailsMatch(_linkedEmail, profileEmail) && profileEmail.isNotEmpty;
    final stored = _linkedEmail?.trim() ?? '';
    final hadStoredEmail = stored.isNotEmpty;
    final needsMigrate =
        student != null && profileEmail.isNotEmpty && hadStoredEmail && !linked;
    final validUntil = DateTime.now().add(const Duration(days: 730));
    final validStr = DateFormat('dd.MM.yyyy').format(validUntil);
    final seed = '${_linkedEmail ?? ''}|${student?.id ?? ''}';
    final digits = _loyaltyCardDigits(seed.isEmpty ? 'guest' : seed);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Карта лояльности',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.blockBlack),
        ),
        const SizedBox(height: 12),
        if (student == null)
          Text(
            'Войдите в аккаунт, чтобы привязать карту к почте профиля.',
            style: TextStyle(fontSize: 14, height: 1.45, color: AppConstants.secondaryColor),
          )
        else if (profileEmail.isEmpty)
          Text(
            'В профиле не указана почта. Оформите карту в боте или уточните данные в деканате.',
            style: TextStyle(fontSize: 14, height: 1.45, color: AppConstants.secondaryColor),
          )
        else if (linked)
          _buildLoyaltyCard(
            profileEmail: profileEmail,
            student: student,
            digits: digits,
            validStr: validStr,
          )
        else if (needsMigrate)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.terracottaMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppConstants.terracotta.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Карта была привязана к',
                      style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stored,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppConstants.blockBlack),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Сейчас в профиле: $profileEmail',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppConstants.blockBlack),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _saveLoyaltyEmail(profileEmail),
                child: const Text('Перенести карту на почту профиля'),
              ),
              const SizedBox(height: 8),
              Text(
                'Номер карты обновится под новую почту.',
                style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor, height: 1.35),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _openUrl(AppConstants.loyaltyTelegramBotUrl),
                child: const Text('Помощь в Telegram'),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Почта в приложении: $profileEmail',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppConstants.blockBlack),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _saveLoyaltyEmail(profileEmail),
                child: const Text('Привязать карту к этой почте'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => _openUrl(AppConstants.loyaltyTelegramBotUrl),
                child: const Text('Нет карты — оформить в Telegram'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLoyaltyCard({
    required String profileEmail,
    required Student student,
    required String digits,
    required String validStr,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.blockBlack,
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          left: BorderSide(color: AppConstants.terracotta, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profileEmail,
                  style: const TextStyle(
                    color: AppConstants.onBlockSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(PhosphorIconsRegular.checkCircle, color: AppConstants.terracotta, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            digits,
            style: const TextStyle(
              color: AppConstants.onBlock,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            student.fullName,
            style: const TextStyle(color: AppConstants.onBlock, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Действует до $validStr',
            style: const TextStyle(color: AppConstants.onBlockSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPastelShortcutRow(BuildContext context) {
    final items = <(IconData, String, Color, VoidCallback)>[
      (
        PhosphorIconsRegular.student,
        'Портфолио',
        AppConstants.terracottaMuted,
        () => context.read<MainNavProvider>().goToShowcasePortfolio(),
      ),
      (PhosphorIconsRegular.identificationCard, 'Карта', const Color(0xFFDCE6F5), () => _scrollTo(_loyaltyKey)),
      (PhosphorIconsRegular.fileText, 'Документы', const Color(0xFFD8EDE4), () => _openCertificatesSheet(context)),
      (PhosphorIconsRegular.squaresFour, 'Сервисы', const Color(0xFFE8E4F0), () => _openServicesSheet(context)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: items[i].$4,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: items[i].$3,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(items[i].$1, color: AppConstants.blockBlack, size: 24),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      items[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPortfolioSection(BuildContext context) {
    final student = context.watch<StudentProvider>().student;
    final portfolio = context.watch<PortfolioProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Портфолио',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.blockBlack),
              ),
            ),
            if (portfolio.isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.blockBlack),
              ),
          ],
        ),
        if (student != null) ...[
          const SizedBox(height: 10),
          Text(
            '${student.group} · ${student.specialty}',
            style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor, height: 1.35),
          ),
        ],
        const SizedBox(height: 18),
        for (var r = 0; r < PortfolioPedagogySections.rows.length; r++)
          _PortfolioCategoryBlock(
            sectionTitle: PortfolioPedagogySections.rows[r].$1,
            items: PortfolioPedagogySections.rows[r].$2,
            styleIndex: r,
          ),
      ],
    );
  }
}

class _PortfolioCategoryBlock extends StatelessWidget {
  const _PortfolioCategoryBlock({
    required this.sectionTitle,
    required this.items,
    required this.styleIndex,
  });

  final String sectionTitle;
  final List<String> items;
  final int styleIndex;

  static const List<Color> _cardTints = [
    Color(0xFFF8F6F5),
    Color(0xFFF5F7FA),
    Color(0xFFF5FAF7),
    Color(0xFFFAF7F3),
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _cardTints[styleIndex % _cardTints.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              sectionTitle,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppConstants.blockBlack,
                letterSpacing: -0.2,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: w,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => showPortfolioCategorySheet(context, sectionTitle, item),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: tint,
                              borderRadius: BorderRadius.circular(16),
                              border: Border(
                                left: const BorderSide(color: AppConstants.terracotta, width: 3),
                                top: BorderSide(color: AppConstants.borderSubtle),
                                right: BorderSide(color: AppConstants.borderSubtle),
                                bottom: BorderSide(color: AppConstants.borderSubtle),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: AppConstants.blockBlack,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  PhosphorIconsRegular.caretRight,
                                  size: 16,
                                  color: AppConstants.terracottaDark.withValues(alpha: 0.55),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShowcaseSearchDelegate extends SearchDelegate<void> {
  _ShowcaseSearchDelegate({
    required this.onSchedule,
    required this.onHome,
    required this.onOpenPortfolio,
    required this.onScrollLoyalty,
    required this.onServices,
    required this.onCertificates,
    required this.onLabs,
  });

  final VoidCallback onSchedule;
  final VoidCallback onHome;
  final VoidCallback onOpenPortfolio;
  final VoidCallback onScrollLoyalty;
  final VoidCallback onServices;
  final VoidCallback onCertificates;
  final VoidCallback onLabs;

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(PhosphorIconsRegular.x, color: AppConstants.blockBlack),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(PhosphorIconsRegular.caretLeft, color: AppConstants.blockBlack),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final q = query.trim().toLowerCase();
    final items = <_SearchHit>[
      _SearchHit('Расписание', PhosphorIconsRegular.calendarBlank, onSchedule),
      _SearchHit('Главная', PhosphorIconsRegular.house, onHome),
      _SearchHit('Портфолио', PhosphorIconsRegular.student, onOpenPortfolio),
      _SearchHit('Карта лояльности', PhosphorIconsRegular.identificationCard, onScrollLoyalty),
      _SearchHit('Сервисы', PhosphorIconsRegular.squaresFour, onServices),
      _SearchHit('Лабораторные', PhosphorIconsRegular.flask, onLabs),
      _SearchHit('Документы', PhosphorIconsRegular.fileText, onCertificates),
    ];

    final filtered = q.isEmpty
        ? items
        : items.where((e) => e.title.toLowerCase().contains(q)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final hit in filtered)
          ListTile(
            leading: Icon(hit.icon, color: AppConstants.blockBlack),
            title: Text(hit.title),
            onTap: () {
              close(context, null);
              hit.onTap();
            },
          ),
      ],
    );
  }
}

class _SearchHit {
  _SearchHit(this.title, this.icon, this.onTap);
  final String title;
  final IconData icon;
  final VoidCallback onTap;
}
