class GradeCalculator {
  static double calculateAverage(List<double> grades) {
    if (grades.isEmpty) return 0.0;
    return grades.reduce((a, b) => a + b) / grades.length;
  }

  static String predictDiplomaGrade(double average) {
    if (average >= 4.5) return '5 (отлично)';
    if (average >= 3.5) return '4 (хорошо)';
    if (average >= 2.5) return '3 (удовлетворительно)';
    return '?';
  }

  static bool isEligibleForHonorsDegree(
      double average,
      int excellentGrades,
      int totalGrades,
      ) {
    if (totalGrades == 0) return false;

    final excellentPercentage = (excellentGrades / totalGrades) * 100;
    return average >= 4.75 && excellentPercentage >= 75;
  }

  static double calculateProgress(int completed, int total) {
    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }
}