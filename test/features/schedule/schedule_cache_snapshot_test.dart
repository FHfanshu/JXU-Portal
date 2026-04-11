import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/schedule/schedule_cache_snapshot.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_model.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_term_context.dart';

void main() {
  test('copyWith can clear timestamps and preserve data', () {
    final snapshot = ScheduleCacheSnapshot(
      studentId: '20250001',
      termContext: const ScheduleTermContext(academicYear: 2025, term: 12),
      courses: const [
        CourseEntry(
          courseName: '大学物理',
          teacherName: '教师',
          weekday: 1,
          startLesson: 1,
          endLesson: 2,
          weekRange: '1-18周',
          classroom: 'A101',
          campus: '梁林校区',
          typeSymbol: '',
        ),
      ],
      scheduleUpdatedAt: DateTime(2026, 4, 1),
      changeRulesUpdatedAt: DateTime(2026, 4, 2),
    );

    final updated = snapshot.copyWith(clearScheduleUpdatedAt: true);

    expect(updated.scheduleUpdatedAt, isNull);
    expect(updated.changeRulesUpdatedAt, DateTime(2026, 4, 2));
    expect(updated.hasData, isTrue);
    expect(updated.lastUpdatedAt, DateTime(2026, 4, 2));
  });

  test('refresh heuristics require schedule data and respect max age', () {
    final empty = ScheduleCacheSnapshot.empty(
      studentId: '20250001',
      termContext: const ScheduleTermContext(academicYear: 2025, term: 12),
    );
    expect(empty.needsScheduleRefresh(DateTime(2026, 4, 10)), isTrue);
    expect(empty.needsChangeRulesRefresh(DateTime(2026, 4, 10)), isTrue);
  });
}
