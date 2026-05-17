class Student {
  final String id;
  final String fullName;
  final String group;
  final String faculty;
  final String specialty;
  final int course;
  final String? avatarUrl;
  final DateTime admissionDate;
  final DateTime graduationDate;
  final String email;
  final String phone;
  final String address;
  final Map<String, dynamic> additionalInfo;

  Student({
    required this.id,
    required this.fullName,
    required this.group,
    required this.faculty,
    required this.specialty,
    required this.course,
    this.avatarUrl,
    required this.admissionDate,
    required this.graduationDate,
    required this.email,
    required this.phone,
    required this.address,
    required this.additionalInfo,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? '',
      fullName: json['fullName'] ?? '',
      group: json['group'] ?? '',
      faculty: json['faculty'] ?? '',
      specialty: json['specialty'] ?? '',
      course: json['course'] ?? 0,
      avatarUrl: json['avatarUrl'],
      admissionDate: DateTime.parse(json['admissionDate']),
      graduationDate: DateTime.parse(json['graduationDate']),
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      additionalInfo: Map<String, dynamic>.from(json['additionalInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'group': group,
      'faculty': faculty,
      'specialty': specialty,
      'course': course,
      'avatarUrl': avatarUrl,
      'admissionDate': admissionDate.toIso8601String(),
      'graduationDate': graduationDate.toIso8601String(),
      'email': email,
      'phone': phone,
      'address': address,
      'additionalInfo': additionalInfo,
    };
  }
}