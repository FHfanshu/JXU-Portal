import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/grades/grades_model.dart';

void main() {
  group('GradeEntry.fromJson', () {
    test('parses complete grade payload', () {
      final entry = GradeEntry.fromJson({
        'kcmc': '高等数学',
        'cj': '优秀',
        'bfzcj': '95',
        'jd': '4.8',
        'xf': '5.0',
        'xnmmc': '2025-2026',
        'xqmmc': '第一学期',
        'ksxz': '正常考试',
        'khfsmc': '考试',
        'kcxzmc': '必修',
      });

      expect(entry.courseName, '高等数学');
      expect(entry.grade, '优秀');
      expect(entry.percentageScore, '95');
      expect(entry.gpaPoints, 4.8);
      expect(entry.credits, 5.0);
      expect(entry.academicYear, '2025-2026');
      expect(entry.semester, '第一学期');
      expect(entry.examType, '正常考试');
      expect(entry.assessmentMethod, '考试');
      expect(entry.courseRequirement, '必修');
    });

    test('falls back safely for missing and invalid values', () {
      final entry = GradeEntry.fromJson({
        'kcmc': null,
        'jd': 'NaN',
        'xf': 'invalid',
      });

      expect(entry.courseName, '');
      expect(entry.grade, '');
      expect(entry.percentageScore, '');
      expect(entry.gpaPoints.isNaN, isTrue);
      expect(entry.credits, 0.0);
      expect(entry.academicYear, '');
      expect(entry.semester, '');
      expect(entry.examType, '');
      expect(entry.assessmentMethod, '');
      expect(entry.courseRequirement, '');
    });
  });
}
