import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:tsput_profile/ui/auth/login_screen.dart';
import 'package:tsput_profile/ui/splash/entry_splash_screen.dart';
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
import 'core/providers/labs_provider.dart';
import 'core/providers/main_nav_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru_RU', null);

  runApp(MyApp());
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
        title: 'ТГПУ профиль',
        debugShowCheckedModeBanner: false,
        theme: AppThemes.lightTheme,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          const Locale('ru', 'RU'),
        ],
        home: EntrySplashScreen(child: AuthWrapper()),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isAuthenticated) {
      return FutureBuilder(
        future: _loadAllData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: AppConstants.backgroundColor,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppConstants.primaryColor),
                    SizedBox(height: 16),
                    Text(
                      'Загрузка данных...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return MainNavigation();
        },
      );
    } else {
      return LoginScreen(
        onLoginSuccess: () {
          context.read<AuthProvider>().setAuthenticated(true);
        },
      );
    }
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

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  static final List<Widget> _screens = [
    const HomeScreen(),
    const ScheduleScreen(),
    const ShowcaseScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<MainNavProvider>();
    return Scaffold(
      body: IndexedStack(
        index: nav.index,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8E8E6))),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: nav.index,
          onTap: (index) => context.read<MainNavProvider>().setTab(index),
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.house),
              activeIcon: Icon(PhosphorIconsFill.house),
              label: 'главная',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.calendarBlank),
              activeIcon: Icon(PhosphorIconsFill.calendarBlank),
              label: 'расписание',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.squaresFour),
              activeIcon: Icon(PhosphorIconsFill.squaresFour),
              label: 'витрина',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.user),
              activeIcon: Icon(PhosphorIconsFill.user),
              label: 'профиль',
            ),
          ],
        ),
      ),
    );
  }
}