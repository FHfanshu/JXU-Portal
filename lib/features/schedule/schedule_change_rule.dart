import 'schedule_model.dart';

enum CourseChangeType { cancel, reschedule, makeup }

class CourseLessonSlot {
  const CourseLessonSlot({
    required this.week,
    required this.weekday,
    required this.startLesson,
    required this.endLesson,
  });

  final int week;
  final int weekday;
  final int startLesson;
  final int endLesson;

  bool overlaps(CourseEntry course) {
    if (weekday != course.weekday) return false;
    return course.startLesson <= endLesson && course.endLesson >= startLesson;
  }

  String get signature => '$week-$weekday-$startLesson-$endLesson';

  Map<String, dynamic> toJson() => {
    'week': week,
    'weekday': weekday,
    'startLesson': startLesson,
    'endLesson': endLesson,
  };

  factory CourseLessonSlot.fromJson(Map<String, dynamic> json) {
    return CourseLessonSlot(
      week: json['week'] as int? ?? 0,
      weekday: json['weekday'] as int? ?? 0,
      startLesson: json['startLesson'] as int? ?? 0,
      endLesson: json['endLesson'] as int? ?? 0,
    );
  }
}

class CourseChangeRule {
  const CourseChangeRule({
    required this.type,
    this.originalLesson,
    this.targetLesson,
    this.courseName,
    this.teacherName,
    this.classroom,
  });

  final CourseChangeType type;
  final CourseLessonSlot? originalLesson;
  final CourseLessonSlot? targetLesson;
  final String? courseName;
  final String? teacherName;
  final String? classroom;

  bool removesCourse(CourseEntry course, int week) {
    final lesson = originalLesson;
    if (lesson == null || lesson.week != week || !lesson.overlaps(course)) {
      return false;
    }

    final ruleCourseName = courseName?.trim() ?? '';
    if (ruleCourseName.isEmpty) return true;

    return _matchesCourseName(course.courseName, ruleCourseName);
  }

  bool addsCourseToWeek(int week) => targetLesson?.week == week;

  String get signature => [
    type.name,
    originalLesson?.signature ?? '',
    targetLesson?.signature ?? '',
    courseName ?? '',
    teacherName ?? '',
    classroom ?? '',
  ].join('|');

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'originalLesson': originalLesson?.toJson(),
    'targetLesson': targetLesson?.toJson(),
    'courseName': courseName,
    'teacherName': teacherName,
    'classroom': classroom,
  };

  factory CourseChangeRule.fromJson(Map<String, dynamic> json) {
    return CourseChangeRule(
      type: CourseChangeType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => CourseChangeType.cancel,
      ),
      originalLesson: _slotFromJson(json['originalLesson']),
      targetLesson: _slotFromJson(json['targetLesson']),
      courseName: json['courseName']?.toString(),
      teacherName: json['teacherName']?.toString(),
      classroom: json['classroom']?.toString(),
    );
  }

  static CourseLessonSlot? _slotFromJson(Object? value) {
    if (value is Map<String, dynamic>) {
      return CourseLessonSlot.fromJson(value);
    }
    return null;
  }
}

String normalizeCourseName(String value) {
  return value.toLowerCase().replaceAll(
    RegExp('[\\s\\-—_（）()【】\\[\\]<>《》,，.。:：;；"\\\'、/+]+'),
    '',
  );
}

bool _matchesCourseName(String left, String right) {
  final a = normalizeCourseName(left);
  final b = normalizeCourseName(right);
  if (a.isEmpty || b.isEmpty) return false;
  return a.contains(b) || b.contains(a);
}
