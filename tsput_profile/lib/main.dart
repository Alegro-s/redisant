import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:tsput_profile/ui/auth/login_screen.dart';
import 'package:tsput_profile/ui/screens/home_screen.dart';
import 'package:tsput_profile/ui/screens/showcase_screen.dart';
import 'package:tsput_profile/ui/screens/profile_screen.dart';
import 'package:tsput_profile/ui/screens/schedule_screen.dart';
import 'core/providers/auth_provider.dart';
import 'core/constants.dart';
import 'core/themes.dart';
import 'core/providers/student_provider.dart';
import 'core/providers/schedule_provider.dart';
import 'core/providers/events_provider.dart';
import 'core/providers/grades_provider.dart';
import 'core/providers/exams_provider.dart';
import 'core/providers/portfolio_provider.dart';
import 'core/in_app_notification_tracker.dart';
import 'core/providers/labs_provider.dart';
import 'ui/widgets/app_motion.dart';
import 'ui/widgets/in_app_notice_sheet.dart';
import 'core/providers/main_nav_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => EventsProvider()),
        ChangeNotifierProvider(create: (_) => GradesProvider()),
        ChangeNotifierProvider(create: (_) => ExamsProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => LabsProvider()),
        ChangeNotifierProvider(create: (_) => MainNavProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru', 'RU')],
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.initializing) {
      return const Scaffold(
        backgroundColor: AppConstants.surfaceWhite,
        body: Center(child: CircularProgressIndicator(color: AppConstants.blockBlack)),
      );
    }

    if (auth.isAuthenticated) {
      return FutureBuilder(
        future: _loadAllData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: AppConstants.surfaceWhite,
              body: Center(child: CircularProgressIndicator(color: AppConstants.blockBlack)),
            );
          }
          return const MainNavigation();
        },
      );
    }

    return LoginScreen(
      onLoginSuccess: () => context.read<AuthProvider>().setAuthenticated(true),
    );
  }

  Future<void> _loadAllData(BuildContext context) async {
    await Future.wait([
      context.read<StudentProvider>().loadStudentData(),
      context.read<ScheduleProvider>().loadSchedule(),
      context.read<GradesProvider>().loadGrades(),
      context.read<ExamsProvider>().loadExams(),
      context.read<PortfolioProvider>().loadPortfolio(),
      context.read<LabsProvider>().loadLabs(),
    ]);
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  static const _screenCount = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDataNotifications());
  }

  Future<void> _checkDataNotifications() async {
    if (!mounted) return;
    final schedule = context.read<ScheduleProvider>().schedule;
    final labs = context.read<LabsProvider>().labs;
    if (schedule.isEmpty && labs.isEmpty) return;

    final changes = await InAppNotificationTracker.detectChanges(schedule: schedule, labs: labs);
    if (!mounted) return;

    if (changes.scheduleChanged) {
      await showInAppNoticeSheet(
        context,
        title: 'Расписание обновлено',
        message: 'Появились изменения в расписании. Откройте вкладку «Расписание».',
        icon: PhosphorIconsRegular.calendarBlank,
      );
    } else if (changes.labsChanged) {
      await showInAppNoticeSheet(
        context,
        title: 'Moodle',
        message: 'Обновились статусы лабораторных или комментарии преподавателя.',
        icon: PhosphorIconsRegular.flask,
        accent: AppConstants.terracottaDark,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<MainNavProvider>();
    return Scaffold(
      body: IndexedStack(
        index: nav.index,
        children: [
          for (var i = 0; i < _screenCount; i++)
            AppTabEnter(
              active: nav.index == i,
              child: switch (i) {
                0 => const HomeScreen(),
                1 => const ScheduleScreen(),
                2 => const ShowcaseScreen(),
                _ => const ProfileScreen(),
              },
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8E8E6)))),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: nav.index,
          onTap: (index) => context.read<MainNavProvider>().setTab(index),
          items: const [
            BottomNavigationBarItem(icon: Icon(PhosphorIconsRegular.house), activeIcon: Icon(PhosphorIconsFill.house), label: 'главная'),
            BottomNavigationBarItem(icon: Icon(PhosphorIconsRegular.calendarBlank), activeIcon: Icon(PhosphorIconsFill.calendarBlank), label: 'расписание'),
            BottomNavigationBarItem(icon: Icon(PhosphorIconsRegular.squaresFour), activeIcon: Icon(PhosphorIconsFill.squaresFour), label: 'витрина'),
            BottomNavigationBarItem(icon: Icon(PhosphorIconsRegular.user), activeIcon: Icon(PhosphorIconsFill.user), label: 'профиль'),
          ],
        ),
      ),
    );
  }
}
