
class DemoStudent {
  DemoStudent._();

  static Map<String, dynamic> toJson() => {
        'id': 'ST001',
        'fullName': 'Виноградов Игорь Денисович',
        'group': '1521621',
        'faculty': 'Институт передовых информационных технологий',
        'specialty': 'Математическое обеспечение и администрирование информационных систем',
        'course': 4,
        'admissionDate': '2022-09-01T00:00:00.000Z',
        'graduationDate': '2026-06-30T00:00:00.000Z',
        'email': 'lorm2053@gmail.com',
        'phone': '+7 (900) 000-00-00',
        'address': 'г. Тула',
        'additionalInfo': {
          'recordBook': '22031-15',
          'educationForm': 'Очная',
          'city': 'Tula',
          'timezone': 'Etc/GMT-3',
          'birthDate': '2004-10-21',
          'studentStatus': 'Является студентом',
          'trainingLevel': 'Бакалавриат',
          'profile': 'Информационные системы и базы данных',
          'scholarship': 0,
          'dormitory': 'Не указано',
          'averageGrade': 4.7,
          'examsCount': 8,
        },
      };
}
