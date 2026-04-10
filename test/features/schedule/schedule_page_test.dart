import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/core/semester/semester_calendar.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_cache_snapshot.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_model.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_page.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_service.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_term_context.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final today = DateTime.now();
    SharedPreferences.setMockInitialValues({});
    SemesterCalendar.instance.semesterStartDate.value = DateTime(
      today.year,
      today.month,
      today.day,
    );
    await ScheduleService.instance.restoreCache();
    await ScheduleService.instance.debugClearCache();
  });

  testWidgets('shows course change reminders above the schedule grid', (
    tester,
  ) async {
    final now = DateTime.now();
    final termContext = ScheduleTermContext.current(now);

    ScheduleService.instance.debugSetSnapshot(
      ScheduleCacheSnapshot(
        studentId: '2025000001',
        termContext: termContext,
        courses: const [
          CourseEntry(
            courseName: 'AI+创新创业基础',
            teacherName: '胡亚楠',
            weekday: 5,
            startLesson: 8,
            endLesson: 9,
            weekRange: '1-18周',
            classroom: '铭德楼468',
            campus: '梁林校区',
            typeSymbol: '',
          ),
        ],
        changeRules: const [
          CourseChangeRule(
            type: CourseChangeType.reschedule,
            originalLesson: CourseLessonSlot(
              week: 5,
              weekday: 4,
              startLesson: 8,
              endLesson: 9,
            ),
            targetLesson: CourseLessonSlot(
              week: 5,
              weekday: 5,
              startLesson: 8,
              endLesson: 9,
            ),
            courseName: 'AI+创新创业基础',
            teacherName: '胡亚楠',
            classroom: '铭德楼468',
          ),
        ],
        scheduleUpdatedAt: now,
        changeRulesUpdatedAt: now,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SchedulePage()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byTooltip('调课提醒'), findsOneWidget);
    expect(find.text('已根据这些提醒自动修正课表显示'), findsNothing);

    await tester.tap(find.byTooltip('调课提醒'));
    await tester.pumpAndSettle();

    expect(find.text('调课提醒'), findsOneWidget);
    expect(find.text('AI+创新创业基础'), findsWidgets);
    expect(find.textContaining('第5周 周四 第8-9节 -> 第5周 周五 第8-9节'), findsOneWidget);
    expect(find.text('胡亚楠 · 铭德楼468'), findsOneWidget);
  });
}
