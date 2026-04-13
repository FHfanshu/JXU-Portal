import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_cache_snapshot.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_model.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_service.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_term_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScheduleService.instance.restoreCache();
    await ScheduleService.instance.debugClearCache();
  });

  group('ScheduleCacheSnapshot', () {
    test('round-trips course and change rule data', () {
      final snapshot = ScheduleCacheSnapshot(
        studentId: '20230001',
        termContext: const ScheduleTermContext(academicYear: 2025, term: 12),
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
        scheduleUpdatedAt: DateTime(2026, 4, 8, 8, 0),
        changeRulesUpdatedAt: DateTime(2026, 4, 8, 9, 30),
      );

      final restored = ScheduleCacheSnapshot.fromJson(snapshot.toJson());

      expect(restored.studentId, snapshot.studentId);
      expect(restored.termContext.academicYear, 2025);
      expect(restored.termContext.term, 12);
      expect(restored.courses.single.courseName, 'AI+创新创业基础');
      expect(restored.changeRules.single.type, CourseChangeType.reschedule);
      expect(restored.changeRules.single.targetLesson?.weekday, 5);
      expect(restored.lastUpdatedAt, DateTime(2026, 4, 8, 9, 30));
    });

    test('uses separate refresh windows for schedule and change rules', () {
      final snapshot = ScheduleCacheSnapshot(
        studentId: '20230001',
        termContext: const ScheduleTermContext(academicYear: 2025, term: 12),
        scheduleUpdatedAt: DateTime(2026, 4, 1, 8, 0),
        changeRulesUpdatedAt: DateTime(2026, 4, 7, 8, 0),
      );

      expect(
        snapshot.needsScheduleRefresh(
          DateTime(2026, 4, 8, 8, 0),
          maxAge: ScheduleService.scheduleRefreshWindow,
        ),
        isTrue,
      );
      expect(
        snapshot.needsChangeRulesRefresh(
          DateTime(2026, 4, 8, 8, 0),
          maxAge: ScheduleService.changeRuleRefreshWindow,
        ),
        isTrue,
      );
      expect(
        snapshot.needsChangeRulesRefresh(
          DateTime(2026, 4, 7, 20, 0),
          maxAge: ScheduleService.changeRuleRefreshWindow,
        ),
        isFalse,
      );
    });
  });

  group('ScheduleService cache selection', () {
    test('matches cache by exact student and term', () {
      const currentTerm = ScheduleTermContext(academicYear: 2025, term: 12);
      const otherTerm = ScheduleTermContext(academicYear: 2025, term: 3);

      ScheduleService.instance.debugSetSnapshot(
        ScheduleCacheSnapshot(
          studentId: '20230001',
          termContext: currentTerm,
          courses: const [
            CourseEntry(
              courseName: 'A班课表',
              teacherName: '教师A',
              weekday: 1,
              startLesson: 1,
              endLesson: 2,
              weekRange: '1-18周',
              classroom: '101',
              campus: '嘉兴校区',
              typeSymbol: '',
            ),
          ],
          scheduleUpdatedAt: DateTime(2026, 4, 8, 8, 0),
        ),
      );
      ScheduleService.instance.debugSetSnapshot(
        ScheduleCacheSnapshot(
          studentId: '20230001',
          termContext: otherTerm,
          courses: const [
            CourseEntry(
              courseName: '上学期课表',
              teacherName: '教师B',
              weekday: 2,
              startLesson: 3,
              endLesson: 4,
              weekRange: '1-18周',
              classroom: '202',
              campus: '嘉兴校区',
              typeSymbol: '',
            ),
          ],
          scheduleUpdatedAt: DateTime(2026, 4, 8, 8, 0),
        ),
      );
      ScheduleService.instance.debugSetSnapshot(
        ScheduleCacheSnapshot(
          studentId: '20230002',
          termContext: currentTerm,
          courses: const [
            CourseEntry(
              courseName: 'B班课表',
              teacherName: '教师C',
              weekday: 3,
              startLesson: 5,
              endLesson: 6,
              weekRange: '1-18周',
              classroom: '303',
              campus: '嘉兴校区',
              typeSymbol: '',
            ),
          ],
          scheduleUpdatedAt: DateTime(2026, 4, 8, 8, 0),
        ),
      );

      expect(
        ScheduleService.instance
            .preferredSnapshot(studentId: '20230001', termContext: currentTerm)
            ?.courses
            .single
            .courseName,
        'A班课表',
      );
      expect(
        ScheduleService.instance
            .preferredSnapshot(studentId: '20230001', termContext: otherTerm)
            ?.courses
            .single
            .courseName,
        '上学期课表',
      );
      expect(
        ScheduleService.instance
            .preferredSnapshot(studentId: '20230002', termContext: currentTerm)
            ?.courses
            .single
            .courseName,
        'B班课表',
      );
    });

    test(
      'returns cached snapshot without refresh when cache is fresh',
      () async {
        const termContext = ScheduleTermContext(academicYear: 2025, term: 12);
        ScheduleService.instance.debugSetSnapshot(
          ScheduleCacheSnapshot(
            studentId: '20230001',
            termContext: termContext,
            courses: const [
              CourseEntry(
                courseName: '缓存课表',
                teacherName: '教师A',
                weekday: 1,
                startLesson: 1,
                endLesson: 2,
                weekRange: '1-18周',
                classroom: '101',
                campus: '嘉兴校区',
                typeSymbol: '',
              ),
            ],
            scheduleUpdatedAt: DateTime.now(),
            changeRulesUpdatedAt: DateTime.now(),
          ),
        );

        final result = await ScheduleService.instance.loadScheduleSnapshot(
          studentId: '20230001',
          termContext: termContext,
        );

        expect(result.usedCache, isTrue);
        expect(result.didRefresh, isFalse);
        expect(result.snapshot?.courses.single.courseName, '缓存课表');
      },
    );

    test('keeps stale cache visible when refresh requires login', () async {
      const termContext = ScheduleTermContext(academicYear: 2025, term: 12);
      ScheduleService.instance.debugSetSnapshot(
        ScheduleCacheSnapshot(
          studentId: '20230001',
          termContext: termContext,
          courses: const [
            CourseEntry(
              courseName: '旧课表',
              teacherName: '教师A',
              weekday: 1,
              startLesson: 1,
              endLesson: 2,
              weekRange: '1-18周',
              classroom: '101',
              campus: '嘉兴校区',
              typeSymbol: '',
            ),
          ],
          scheduleUpdatedAt: DateTime.now().subtract(
            ScheduleService.scheduleRefreshWindow + const Duration(hours: 1),
          ),
          changeRulesUpdatedAt: DateTime.now().subtract(
            ScheduleService.changeRuleRefreshWindow + const Duration(hours: 1),
          ),
        ),
      );

      final result = await ScheduleService.instance.loadScheduleSnapshot(
        studentId: '20230001',
        termContext: termContext,
      );

      expect(result.requiresLogin, isTrue);
      expect(result.usedCache, isTrue);
      expect(result.snapshot?.courses.single.courseName, '旧课表');
      expect(result.message, contains('缓存'));
    });
  });

  group('ScheduleService.parseCourseChangeMessages', () {
    test('parses reschedule, makeup and cancellation messages', () {
      final rules = ScheduleService.instance.parseCourseChangeMessages([
        '调课提醒:胡亚楠老师于第5周星期四第8-9节在铭德楼467上的AI+创新创业基础课程调课到由胡亚楠老师在第5周星期五第8-9节在铭德楼468上的AI+创新创业基础课程，请各位同学相互告知！',
        '补课提醒:杨月红老师将在第17周星期六第11-12节对课程健身1进行补课，请各位同学相互告知！',
        '停课提醒:原定汤龙老师在第3周星期一第11-13节于尚德楼142上的政治经济学课程停课，请各位同学相互告知！',
      ]);

      expect(rules, hasLength(3));

      final rescheduleRule = rules.firstWhere(
        (rule) => rule.type == CourseChangeType.reschedule,
      );
      expect(rescheduleRule.courseName, 'AI+创新创业基础');
      expect(rescheduleRule.originalLesson?.week, 5);
      expect(rescheduleRule.originalLesson?.weekday, 4);
      expect(rescheduleRule.targetLesson?.weekday, 5);
      expect(rescheduleRule.classroom, '铭德楼468');

      final makeupRule = rules.firstWhere(
        (rule) => rule.type == CourseChangeType.makeup,
      );
      expect(makeupRule.courseName, '健身1');
      expect(makeupRule.targetLesson?.week, 17);
      expect(makeupRule.targetLesson?.weekday, 6);

      final cancelRule = rules.firstWhere(
        (rule) => rule.type == CourseChangeType.cancel,
      );
      expect(cancelRule.courseName, '政治经济学');
      expect(cancelRule.originalLesson?.week, 3);
      expect(cancelRule.originalLesson?.startLesson, 11);
      expect(cancelRule.originalLesson?.endLesson, 13);
    });
  });

  group('ScheduleService.buildEffectiveWeekCourses', () {
    test('replaces original class with adjusted class in the same week', () {
      const baseCourses = [
        CourseEntry(
          courseName: 'AI+创新创业基础',
          teacherName: '胡亚楠',
          weekday: 4,
          startLesson: 8,
          endLesson: 9,
          weekRange: '1-18周',
          classroom: '铭德楼467',
          campus: '梁林校区',
          typeSymbol: '',
        ),
      ];

      final rules = ScheduleService.instance.parseCourseChangeMessages([
        '调课提醒:胡亚楠老师于第5周星期四第8-9节在铭德楼467上的AI+创新创业基础课程调课到由胡亚楠老师在第5周星期五第8-9节在铭德楼468上的AI+创新创业基础课程，请各位同学相互告知！',
      ]);

      final weekCourses = ScheduleService.instance.buildEffectiveWeekCourses(
        courses: baseCourses,
        week: 5,
        changeRules: rules,
      );

      expect(weekCourses.where((course) => course.weekday == 4), isEmpty);
      expect(weekCourses.where((course) => course.weekday == 5), hasLength(1));
      expect(weekCourses.single.classroom, '铭德楼468');
    });

    test('adds makeup class for target week only', () {
      const baseCourses = [
        CourseEntry(
          courseName: '健身1',
          teacherName: '杨月红',
          weekday: 3,
          startLesson: 6,
          endLesson: 7,
          weekRange: '1-16周',
          classroom: '嘉兴体育馆健身房',
          campus: '嘉兴校区',
          typeSymbol: '',
        ),
      ];

      final rules = ScheduleService.instance.parseCourseChangeMessages([
        '补课提醒:杨月红老师将在第17周星期六第11-12节对课程健身1进行补课，请各位同学相互告知！',
      ]);

      final week17Courses = ScheduleService.instance.buildEffectiveWeekCourses(
        courses: baseCourses,
        week: 17,
        changeRules: rules,
      );
      final week16Courses = ScheduleService.instance.buildEffectiveWeekCourses(
        courses: baseCourses,
        week: 16,
        changeRules: rules,
      );

      expect(
        week17Courses.where((course) => course.weekday == 6),
        hasLength(1),
      );
      expect(
        week17Courses.any((course) => course.classroom == '嘉兴体育馆健身房'),
        isTrue,
      );
      expect(week16Courses.where((course) => course.weekday == 6), isEmpty);
    });
  });
}
