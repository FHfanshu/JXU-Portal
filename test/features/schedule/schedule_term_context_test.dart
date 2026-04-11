import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/schedule/schedule_term_context.dart';

void main() {
  test('current uses academic year rollover and term mapping', () {
    expect(ScheduleTermContext.current(DateTime(2026, 3, 1)).key, '2025-12');
    expect(ScheduleTermContext.current(DateTime(2026, 9, 1)).key, '2026-3');
  });

  test('json round-trip keeps fields and label', () {
    final context = ScheduleTermContext.fromJson({
      'academicYear': 2025,
      'term': 12,
    });

    expect(context.termLabel, '第二学期');
    expect(context.toJson(), {'academicYear': 2025, 'term': 12});
  });
}
