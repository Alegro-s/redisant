class User {
  final String id;
  final String email;
  final String? phone;
  final String fullName;
  final String nickname;
  final String? avatarUrl;
  final DateTime createdAt;
  final Map<String, dynamic> settings;
  final List<String> realms;

  final bool emailVerified;

  User({
    required this.id,
    required this.email,
    this.phone,
    required this.fullName,
    required this.nickname,
    this.avatarUrl,
    required this.createdAt,
    required this.settings,
    required this.realms,
    this.emailVerified = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? 'user',
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      settings: _settingsMap(json['settings']),
      realms: _realmsList(json['realms']),
      emailVerified: json['email_verified'] != false,
    );
  }

  static List<String> _realmsList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const ['nexus', 'metric'];
  }

  static Map<String, dynamic> _settingsMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return {};
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'nickname': nickname,
    'avatar_url': avatarUrl,
    'created_at': createdAt.toIso8601String(),
    'settings': settings,
    'realms': realms,
    'email_verified': emailVerified,
  };

  User copyWith({
    String? fullName,
    String? avatarUrl,
    Map<String, dynamic>? settings,
    List<String>? realms,
  }) {
    return User(
      id: id,
      email: email,
      phone: phone,
      fullName: fullName ?? this.fullName,
      nickname: nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      settings: settings ?? this.settings,
      realms: realms ?? this.realms,
      emailVerified: emailVerified,
    );
  }
}