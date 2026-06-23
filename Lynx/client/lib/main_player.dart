import 'package:client/features/game/game_player_screen.dart';
import 'package:client/features/player/player_paths.dart';
import 'package:flutter/material.dart';

/// Lynx Player — только игра, без редактора и Hub.
/// Сборка: `flutter run -t lib/main_player.dart` (рядом папка `game_data/`).
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final projectPath = await resolvePlayerProjectRoot();
  runApp(LynxPlayerApp(projectPath: projectPath));
}

class LynxPlayerApp extends StatelessWidget {
  final String? projectPath;
  const LynxPlayerApp({super.key, this.projectPath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lynx Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D1B7B)),
        useMaterial3: true,
      ),
      home: projectPath != null
          ? GamePlayerScreen(
              projectPath: projectPath,
              freshPlay: true,
              standalonePlayer: true,
            )
          : const _MissingGameDataScreen(),
    );
  }
}

class _MissingGameDataScreen extends StatelessWidget {
  const _MissingGameDataScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lynx Player')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Не найден проект игры',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Положите папку game_data рядом с исполняемым файлом Player '
              '(внутри должен быть project.json).\n\n'
              'Либо соберите с --dart-define=LYNX_GAME_DATA=<путь>.\n\n'
              'Документация: Lynx/docs/EXPORT.md',
            ),
          ],
        ),
      ),
    );
  }
}
