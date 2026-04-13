import 'schedule_model.dart';

class ScheduleDayCourses {
  const ScheduleDayCourses({
    required this.currentWeekCourses,
    required this.otherWeekCourses,
  });

  final List<CourseEntry> currentWeekCourses;
  final List<CourseEntry> otherWeekCourses;
}

class ScheduleWeekViewModel {
  const ScheduleWeekViewModel({required this.week, required this.days});

  final int week;
  final Map<int, ScheduleDayCourses> days;

  ScheduleDayCourses coursesForDay(int day) {
    return days[day] ??
        const ScheduleDayCourses(currentWeekCourses: [], otherWeekCourses: []);
  }
}
