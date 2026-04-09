class ScheduleSlotTimes {
  ScheduleSlotTimes._();

  static const slotTimes = [
    ['08:00', '08:40'],
    ['08:45', '09:25'],
    ['09:45', '10:25'],
    ['10:30', '11:10'],
    ['11:15', '11:55'],
    ['13:30', '14:10'],
    ['14:15', '14:55'],
    ['15:15', '15:55'],
    ['16:00', '16:40'],
    ['16:45', '17:25'],
    ['18:30', '19:10'],
    ['19:15', '19:55'],
    ['20:00', '20:40'],
  ];

  static String startTime(int lesson) =>
      (lesson >= 1 && lesson <= 13) ? slotTimes[lesson - 1][0] : '??';

  static String endTime(int lesson) =>
      (lesson >= 1 && lesson <= 13) ? slotTimes[lesson - 1][1] : '??';

  static String timeRange(int start, int end) =>
      '${startTime(start)}-${endTime(end)}';
}

class CourseEntry {
  const CourseEntry({
    required this.courseName,
    required this.teacherName,
    required this.weekday,
    required this.startLesson,
    required this.endLesson,
    required this.weekRange,
    required this.classroom,
    required this.campus,
    required this.typeSymbol,
  });

  final String courseName;
  final String teacherName;
  final int weekday; // 1=Mon … 7=Sun
  final int startLesson;
  final int endLesson;
  final String weekRange; // e.g. "1-9周,11-16周"
  final String classroom;
  final String campus;
  final String typeSymbol; // ◆★□●◇

  /// 判断课程是否在指定周次（支持"单/双"周修饰符）
  bool isInWeek(int week) {
    final segments = weekRange.replaceAll('周', '').split(',');
    for (final segment in segments) {
      final trimmed = segment.trim();
      final isOddOnly = trimmed.contains('(单)');
      final isEvenOnly = trimmed.contains('(双)');
      final cleaned = trimmed.replaceAll(RegExp(r'\([单双]\)'), '');
      final parts = cleaned.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0].trim()) ?? 0;
        final end = int.tryParse(parts[1].trim()) ?? 0;
        if (week >= start && week <= end) {
          if (isOddOnly && week.isEven) continue;
          if (isEvenOnly && week.isOdd) continue;
          return true;
        }
      } else if (parts.length == 1) {
        final single = int.tryParse(parts[0].trim()) ?? 0;
        if (week == single) return true;
      }
    }
    return false;
  }

  /// 计算课程最近活跃周与 [week] 的距离
  int weekDistanceTo(int week) {
    int minDist = 999;
    final segments = weekRange.replaceAll('周', '').split(',');
    for (final segment in segments) {
      final trimmed = segment.trim();
      final isOddOnly = trimmed.contains('(单)');
      final isEvenOnly = trimmed.contains('(双)');
      final cleaned = trimmed.replaceAll(RegExp(r'\([单双]\)'), '');
      final parts = cleaned.split('-');
      int start = 0, end = 0;
      if (parts.length == 2) {
        start = int.tryParse(parts[0].trim()) ?? 0;
        end = int.tryParse(parts[1].trim()) ?? 0;
      } else if (parts.length == 1) {
        start = end = int.tryParse(parts[0].trim()) ?? 0;
      }
      if (start == 0 && end == 0) continue;
      for (int w = start; w <= end; w++) {
        if (isOddOnly && w.isEven) continue;
        if (isEvenOnly && w.isOdd) continue;
        final d = (w - week).abs();
        if (d < minDist) minDist = d;
        if (d == 0) return 0;
      }
    }
    return minDist;
  }

  factory CourseEntry.fromJson(Map<String, dynamic> json) {
    final storedStartLesson = json['startLesson'] is int
        ? json['startLesson'] as int
        : int.tryParse(json['startLesson']?.toString() ?? '');
    final storedEndLesson = json['endLesson'] is int
        ? json['endLesson'] as int
        : int.tryParse(json['endLesson']?.toString() ?? '');
    final jcs = storedStartLesson != null && storedEndLesson != null
        ? '$storedStartLesson-$storedEndLesson'
        : (json['jcs'] as String? ?? '1-1');
    final parts = jcs.split('-');
    final start = int.tryParse(parts.first.trim()) ?? 1;
    final end = int.tryParse(parts.last.trim()) ?? start;
    return CourseEntry(
      courseName:
          json['courseName'] as String? ?? json['kcmc'] as String? ?? '',
      teacherName:
          json['teacherName'] as String? ?? json['xm'] as String? ?? '',
      weekday:
          (json['weekday'] as int?) ??
          int.tryParse(json['xqj'] as String? ?? '1') ??
          1,
      startLesson: storedStartLesson ?? start,
      endLesson: storedEndLesson ?? end,
      weekRange: json['weekRange'] as String? ?? json['zcd'] as String? ?? '',
      classroom: json['classroom'] as String? ?? json['cdmc'] as String? ?? '',
      campus: json['campus'] as String? ?? json['xqmc'] as String? ?? '',
      typeSymbol:
          json['typeSymbol'] as String? ?? json['xslxbj'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'courseName': courseName,
    'teacherName': teacherName,
    'weekday': weekday,
    'startLesson': startLesson,
    'endLesson': endLesson,
    'weekRange': weekRange,
    'classroom': classroom,
    'campus': campus,
    'typeSymbol': typeSymbol,
  };
}
