class GradeEntry {
  const GradeEntry({
    required this.courseName,
    required this.grade,
    required this.percentageScore,
    required this.gpaPoints,
    required this.credits,
    required this.academicYear,
    required this.semester,
    required this.examType,
    required this.assessmentMethod,
    required this.courseRequirement,
  });

  final String courseName;
  final String grade;
  final String percentageScore;
  final double gpaPoints;
  final double credits;
  final String academicYear;
  final String semester;
  final String examType;
  final String assessmentMethod;
  final String courseRequirement;

  factory GradeEntry.fromJson(Map<String, dynamic> json) {
    return GradeEntry(
      courseName: json['kcmc'] as String? ?? '',
      grade: json['cj'] as String? ?? '',
      percentageScore: json['bfzcj'] as String? ?? '',
      gpaPoints: double.tryParse(json['jd'] as String? ?? '0') ?? 0.0,
      credits: double.tryParse(json['xf'] as String? ?? '0') ?? 0.0,
      academicYear: json['xnmmc'] as String? ?? '',
      semester: json['xqmmc'] as String? ?? '',
      examType: json['ksxz'] as String? ?? '',
      assessmentMethod: json['khfsmc'] as String? ?? '',
      courseRequirement: json['kcxzmc'] as String? ?? '',
    );
  }
}
