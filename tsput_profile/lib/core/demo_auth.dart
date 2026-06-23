
class DemoAuth {
  DemoAuth._();

  static const String demoLogin = 'student@university.ru';
  static const String demoPassword = 'password123';

  static const _localUsers = <_LocalUser>[
    _LocalUser(
      password: 'dE2qAH24',
      identifiers: [
        '24807',
        'lorm2053@gmail.com',
        'Виноградов Игорь Денисович',
        'МОИАИС',
        '1521621',
      ],
      user: {'id': '24807', 'name': 'Виноградов Игорь Денисович', 'group': '1521621 (МОИАИС)'},
    ),
  ];

  static Map<String, dynamic>? tryLogin(String rawLogin, String password) {
    final ident = rawLogin.trim();
    final identCf = ident.toLowerCase();
    final identName = _normalizeName(ident);

    if (identCf == demoLogin.toLowerCase() && password == demoPassword) {
      return _success(
        id: 'ST001',
        name: 'Виноградов Игорь Денисович',
        group: '1521621',
      );
    }

    for (final row in _localUsers) {
      if (row.password != password) continue;
      for (final alias in row.identifiers) {
        final a = alias.trim();
        if (a.isEmpty) continue;
        if (a == ident || a.toLowerCase() == identCf || _normalizeName(a) == identName) {
          return _success(
            id: row.user['id']!,
            name: row.user['name']!,
            group: row.user['group']!,
          );
        }
      }
    }
    return null;
  }

  static Map<String, dynamic> _success({
    required String id,
    required String name,
    required String group,
  }) {
    return {
      'success': true,
      'token': 'demo_${DateTime.now().millisecondsSinceEpoch}',
      'user': {'id': id, 'name': name, 'group': group},
    };
  }

  static String _normalizeName(String value) {
    return value.trim().split(RegExp(r'\s+')).join(' ').toLowerCase();
  }
}

class _LocalUser {
  const _LocalUser({
    required this.password,
    required this.identifiers,
    required this.user,
  });

  final String password;
  final List<String> identifiers;
  final Map<String, String> user;
}
