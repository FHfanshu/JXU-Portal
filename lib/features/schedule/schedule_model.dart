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
    for (final segment in _weekRangeSegmentsFor(weekRange)) {
      if (segment.contains(week)) {
        return true;
      }
    }
    return false;
  }

  /// 计算课程最近活跃周与 [week] 的距离
  int weekDistanceTo(int week) {
    var minDist = 999;
    for (final activeWeek in _distanceWeeksFor(weekRange)) {
      final distance = (activeWeek - week).abs();
      if (distance < minDist) {
        minDist = distance;
        if (distance == 0) {
          return 0;
        }
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

class _WeekRangeSegment {
  const _WeekRangeSegment({
    required this.start,
    required this.end,
    required this.isOddOnly,
    required this.isEvenOnly,
  });

  final int start;
  final int end;
  final bool isOddOnly;
  final bool isEvenOnly;

  bool contains(int week) {
    if (week < start || week > end) return false;

    if (start == end) {
      return true;
    }
    if (isOddOnly && week.isEven) {
      return false;
    }
    if (isEvenOnly && week.isOdd) {
      return false;
    }
    return true;
  }
}

final Map<String, List<_WeekRangeSegment>> _weekRangeSegmentsCache = {};
final Map<String, List<int>> _distanceWeeksCache = {};

List<_WeekRangeSegment> _weekRangeSegmentsFor(String weekRange) {
  return _weekRangeSegmentsCache.putIfAbsent(
    weekRange,
    () => _parseWeekRangeSegments(weekRange),
  );
}

List<int> _distanceWeeksFor(String weekRange) {
  return _distanceWeeksCache.putIfAbsent(
    weekRange,
    () => _collectDistanceWeeks(_weekRangeSegmentsFor(weekRange)),
  );
}

List<_WeekRangeSegment> _parseWeekRangeSegments(String weekRange) {
  if (weekRange.isEmpty) {
    return const [];
  }

  final segments = <_WeekRangeSegment>[];
  for (final rawSegment in weekRange.replaceAll('周', '').split(',')) {
    final trimmed = rawSegment.trim();
    if (trimmed.isEmpty) {
      continue;
    }

    final isOddOnly = trimmed.contains('(单)');
    final isEvenOnly = trimmed.contains('(双)');
    final cleaned = trimmed.replaceAll(RegExp(r'\([单双]\)'), '');
    final parts = cleaned.split('-');

    int start = 0;
    int end = 0;
    if (parts.length == 2) {
      start = int.tryParse(parts[0].trim()) ?? 0;
      end = int.tryParse(parts[1].trim()) ?? 0;
    } else if (parts.length == 1) {
      start = end = int.tryParse(parts[0].trim()) ?? 0;
    }

    if (start == 0 && end == 0) {
      continue;
    }

    segments.add(
      _WeekRangeSegment(
        start: start,
        end: end,
        isOddOnly: isOddOnly,
        isEvenOnly: isEvenOnly,
      ),
    );
  }

  return segments;
}

List<int> _collectDistanceWeeks(List<_WeekRangeSegment> segments) {
  final weeks = <int>[];
  for (final segment in segments) {
    for (var week = segment.start; week <= segment.end; week++) {
      if (segment.isOddOnly && week.isEven) {
        continue;
      }
      if (segment.isEvenOnly && week.isOdd) {
        continue;
      }
      weeks.add(week);
    }
  }
  return weeks;
}
