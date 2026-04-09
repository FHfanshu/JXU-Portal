import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_model.dart';

void main() {
  group('CourseEntry week matching', () {
    const course = CourseEntry(
      courseName: '高等数学',
      teacherName: '张老师',
      weekday: 1,
      startLesson: 1,
      endLesson: 2,
      weekRange: '1-4周,6-10周(单),12周',
      classroom: 'A101',
      campus: '梁林校区',
      typeSymbol: '',
    );

    test('matches regular and odd-week ranges', () {
      expect(course.isInWeek(1), isTrue);
      expect(course.isInWeek(5), isFalse);
      expect(course.isInWeek(7), isTrue);
      expect(course.isInWeek(8), isFalse);
      expect(course.isInWeek(12), isTrue);
    });

    test('computes nearest active week distance', () {
      expect(course.weekDistanceTo(3), 0);
      expect(course.weekDistanceTo(5), 1);
      expect(course.weekDistanceTo(8), 1);
      expect(course.weekDistanceTo(15), 3);
    });
  });

  test('returns fallback distance for empty week range', () {
    const course = CourseEntry(
      courseName: '大学英语',
      teacherName: '李老师',
      weekday: 2,
      startLesson: 3,
      endLesson: 4,
      weekRange: '',
      classroom: 'B202',
      campus: '嘉兴校区',
      typeSymbol: '',
    );

    expect(course.isInWeek(1), isFalse);
    expect(course.weekDistanceTo(1), 999);
  });
}
