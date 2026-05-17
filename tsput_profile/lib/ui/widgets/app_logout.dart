import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/student_provider.dart';
import '../auth/login_screen.dart';

Future<void> performAppLogout(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final student = context.read<StudentProvider>();
  await auth.logout();
  student.clearStudentData();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(AppConstants.loyaltyLinkedEmailPrefKey);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => LoginScreen()),
    (route) => false,
  );
}

void showLogoutConfirmDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Выход'),
        content: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Отмена', style: TextStyle(color: Colors.grey[700])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await performAppLogout(context);
            },
            child: const Text('Выйти', style: TextStyle(color: Color(0xFFB91C1C))),
          ),
        ],
      );
    },
  );
}
