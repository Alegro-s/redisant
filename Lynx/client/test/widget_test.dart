import 'package:client/features/auth/screens/login_screen.dart';
import 'package:client/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Экран входа отображает заголовок «Вход»', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    expect(find.text('Вход'), findsOneWidget);
  });
}
