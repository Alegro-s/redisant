class Teacher {
  final String id;
  final String fullName;
  final String position;
  final String department;
  final String email;
  final String phone;
  final String? photoUrl;
  final List<String> subjects;
  final Map<String, dynamic> schedule;

  Teacher({
    required this.id,
    required this.fullName,
    required this.position,
    required this.department,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.subjects,
    required this.schedule,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      position: json['position'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: json['photoUrl'],
      subjects: List<String>.from(json['subjects'] ?? []),
      schedule: Map<String, dynamic>.from(json['schedule'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'position': position,
      'department': department,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'subjects': subjects,
      'schedule': schedule,
    };
  }
}