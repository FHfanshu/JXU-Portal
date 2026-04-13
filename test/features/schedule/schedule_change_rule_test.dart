import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/schedule/schedule_change_rule.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_model.dart';

void main() {
  const course = CourseEntry(
    courseName: 'AI+创新创业基础',
    teacherName: '胡亚楠',
    weekday: 5,
    startLesson: 8,
    endLesson: 9,
    weekRange: '1-18周',
    classroom: '铭德楼468',
    campus: '梁林校区',
    typeSymbol: '',
  );

  test('normalizeCourseName strips punctuation and brackets', () {
    expect(normalizeCourseName(' AI+创新创业基础（实验） '), 'ai创新创业基础实验');
  });

  test('lesson overlap and removal respect week and fuzzy name matching', () {
    const rule = CourseChangeRule(
      type: CourseChangeType.cancel,
      originalLesson: CourseLessonSlot(
        week: 5,
        weekday: 5,
        startLesson: 8,
        endLesson: 10,
      ),
      courseName: 'AI 创新创业基础',
    );

    expect(rule.removesCourse(course, 5), isTrue);
    expect(rule.removesCourse(course, 6), isFalse);
  });

  test('fromJson defaults unknown type to cancel', () {
    final rule = CourseChangeRule.fromJson({
      'type': 'unknown',
      'originalLesson': {
        'week': 6,
        'weekday': 2,
        'startLesson': 3,
        'endLesson': 4,
      },
    });

    expect(rule.type, CourseChangeType.cancel);
    expect(rule.originalLesson?.signature, '6-2-3-4');
  });
}
