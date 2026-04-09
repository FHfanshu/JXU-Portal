import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/semester/semester_calendar.dart';
import '../../shared/widgets/login_widget.dart';
import 'schedule_cache_snapshot.dart';
import 'schedule_model.dart';
import 'schedule_service.dart';
import 'schedule_term_context.dart';
import 'schedule_week_view_model.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  static const _weekCount = 20;

  bool _loggedIn = false;
  bool _loading = false;
  String? _error;
  String? _infoMessage;
  List<CourseEntry> _courses = [];
  List<CourseChangeRule> _courseChangeRules = const [];
  late ScheduleTermContext _termContext;
  late int _term;
  int _displayWeek = 1;
  DateTime? _scheduleUpdatedAt;
  late final PageController _weekPageController;
  final Map<int, ScheduleWeekViewModel> _weekViewModels = {};

  int get _currentWeek => SemesterCalendar.instance.weekForDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    _termContext = ScheduleService.instance.getCurrentTermContext();
    _term = _termContext.term;
    _displayWeek = _currentWeek;
    _weekPageController = PageController(initialPage: _displayWeek - 1);
    _loggedIn = ZhengfangAuth.instance.isLoggedIn;
    _restoreCachedSnapshot();
    if (_loggedIn || _courses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fetchSchedule();
      });
    }
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  void _onWeekPageChanged(int index) {
    final nextWeek = index + 1;
    if (nextWeek == _displayWeek) return;
    setState(() => _displayWeek = nextWeek);
    _primeNearbyWeekViewModels(nextWeek);
  }

  void _restoreCachedSnapshot() {
    final snapshot = ScheduleService.instance.preferredSnapshot(
      termContext: _activeTermContext,
    );
    if (snapshot == null || !snapshot.hasData) {
      _courses = [];
      _courseChangeRules = const [];
      _scheduleUpdatedAt = null;
      _infoMessage = null;
      _weekViewModels.clear();
      return;
    }

    _applySnapshot(snapshot);
    if (!_loggedIn) {
      _infoMessage = '显示的是本地缓存课表，刷新需要重新登录教务';
    }
  }

  ScheduleTermContext get _activeTermContext =>
      _termContext.copyWith(term: _term);

  void _applySnapshot(ScheduleCacheSnapshot snapshot) {
    _courses = snapshot.courses;
    _courseChangeRules = snapshot.changeRules;
    _scheduleUpdatedAt = snapshot.lastUpdatedAt;
    _weekViewModels.clear();
    _primeNearbyWeekViewModels(_displayWeek);
  }

  void _primeWeekViewModel(int week) {
    if (_courses.isEmpty || week < 1 || week > _weekCount) return;
    _weekViewModels.putIfAbsent(week, () => _buildWeekViewModel(week));
  }

  void _primeNearbyWeekViewModels(int centerWeek) {
    for (final week in [centerWeek - 1, centerWeek, centerWeek + 1]) {
      _primeWeekViewModel(week);
    }
  }

  ScheduleWeekViewModel _buildWeekViewModel(int week) {
    final effectiveWeekCourses = ScheduleService.instance
        .buildEffectiveWeekCourses(
          courses: _courses,
          week: week,
          changeRules: _courseChangeRules,
        );

    final currentWeekCoursesByDay = <int, List<CourseEntry>>{
      for (int day = 1; day <= 7; day++) day: <CourseEntry>[],
    };
    for (final course in effectiveWeekCourses) {
      currentWeekCoursesByDay[course.weekday]?.add(course);
    }

    final otherWeekCoursesByDay = <int, List<CourseEntry>>{
      for (int day = 1; day <= 7; day++) day: <CourseEntry>[],
    };
    for (final course in _courses) {
      if (course.isInWeek(week)) {
        continue;
      }
      otherWeekCoursesByDay[course.weekday]?.add(course);
    }

    final days = <int, ScheduleDayCourses>{};
    for (int day = 1; day <= 7; day++) {
      final dayCurrent = _ScheduleGrid.mergeAdjacentCourses(
        currentWeekCoursesByDay[day]!,
      );
      final dayOther = _ScheduleGrid.deduplicateBySlot(
        otherWeekCoursesByDay[day]!,
        dayCurrent,
      );
      days[day] = ScheduleDayCourses(
        currentWeekCourses: dayCurrent,
        otherWeekCourses: dayOther,
      );
    }
    return ScheduleWeekViewModel(week: week, days: days);
  }

  ScheduleWeekViewModel _weekViewModelFor(int week) {
    return _weekViewModels.putIfAbsent(week, () => _buildWeekViewModel(week));
  }

  Future<void> _fetchSchedule({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      if (_courses.isEmpty) {
        _error = null;
      }
    });

    try {
      final result = await ScheduleService.instance.loadScheduleSnapshot(
        termContext: _activeTermContext,
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      setState(() {
        _loggedIn = ZhengfangAuth.instance.isLoggedIn;
        _infoMessage = null;

        final snapshot = result.snapshot;
        if (snapshot != null && snapshot.hasData) {
          _applySnapshot(snapshot);
          _error = null;
        }

        if (result.message != null) {
          if (_courses.isNotEmpty) {
            _infoMessage = result.message;
          } else {
            _error = result.message;
          }
        } else if (!_loggedIn && _courses.isNotEmpty) {
          _infoMessage = '显示的是本地缓存课表，刷新需要重新登录教务';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _loggedIn = true;
      _error = null;
      _infoMessage = null;
    });
    _fetchSchedule(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课表'),
        actions: (_loggedIn || _courses.isNotEmpty)
            ? [
                PopupMenuButton<int>(
                  icon: const Icon(Icons.calendar_today),
                  tooltip: '切换学期',
                  onSelected: (v) {
                    setState(() {
                      _term = v;
                      _displayWeek = _currentWeek;
                    });
                    if (_weekPageController.hasClients) {
                      _weekPageController.jumpToPage(_displayWeek - 1);
                    }
                    _restoreCachedSnapshot();
                    _fetchSchedule();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 3, child: Text('第一学期')),
                    PopupMenuItem(value: 12, child: Text('第二学期')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => _fetchSchedule(forceRefresh: true),
                ),
              ]
            : null,
      ),
      body: (_loggedIn || _courses.isNotEmpty)
          ? _buildScheduleBody()
          : _buildLoginBody(),
    );
  }

  Widget _buildLoginBody() => LoginWidget(onLoginSuccess: _onLoginSuccess);

  Widget _buildScheduleBody() {
    if (_loading && _courses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _fetchSchedule(forceRefresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂无课表数据'),
            const SizedBox(height: 12),
            if (_loggedIn)
              FilledButton(
                onPressed: () => _fetchSchedule(forceRefresh: true),
                child: const Text('刷新课表'),
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_infoMessage != null || _scheduleUpdatedAt != null)
          _ScheduleInfoBanner(
            message: _infoMessage,
            updatedAt: _scheduleUpdatedAt,
            loggedIn: _loggedIn,
          ),
        Expanded(child: _buildWeekPager()),
      ],
    );
  }

  Widget _buildWeekPager() {
    return PageView.builder(
      controller: _weekPageController,
      itemCount: _weekCount,
      onPageChanged: _onWeekPageChanged,
      allowImplicitScrolling: true,
      dragStartBehavior: DragStartBehavior.down,
      itemBuilder: (context, index) {
        final week = index + 1;
        final weekViewModel = _weekViewModelFor(week);
        return RepaintBoundary(
          child: _ScheduleGrid(
            key: ValueKey('week-grid-$week'),
            weekViewModel: weekViewModel,
            actualCurrentWeek: _currentWeek,
          ),
        );
      },
    );
  }
}

class _ScheduleInfoBanner extends StatelessWidget {
  const _ScheduleInfoBanner({
    required this.message,
    required this.updatedAt,
    required this.loggedIn,
  });

  final String? message;
  final DateTime? updatedAt;
  final bool loggedIn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[
      if ((message ?? '').isNotEmpty) message!,
      if (updatedAt != null) '最近更新 ${_formatDateTime(updatedAt!)}',
      if (!loggedIn && updatedAt != null) '当前仅展示缓存',
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    super.key,
    required this.weekViewModel,
    required this.actualCurrentWeek,
  });

  final ScheduleWeekViewModel weekViewModel;
  final int actualCurrentWeek;
  int get currentWeek => weekViewModel.week;

  static const _slotColumnWidth = 48.0;
  static const _slotHeight = 68.0;

  static const _courseColors = [
    Color(0xFF8B1A2D),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFD4AF37),
    Color(0xFF7B1FA2),
    Color(0xFF00838F),
    Color(0xFFE65100),
    Color(0xFFAD1457),
  ];

  static const _inactiveColors = [
    Color(0xFFD4A5B0),
    Color(0xFFA5C4E0),
    Color(0xFFA5D4A5),
    Color(0xFFE0D4A5),
    Color(0xFFC4A5D4),
    Color(0xFFA5D4D4),
    Color(0xFFE0BFA5),
    Color(0xFFD4A5C4),
  ];

  /// Merge adjacent/overlapping same-name courses on the same day into one
  /// entry spanning the full range, then deduplicate.
  static List<CourseEntry> mergeAdjacentCourses(List<CourseEntry> courses) {
    if (courses.length <= 1) return courses;

    // Group by courseName (already filtered to same weekday by caller)
    final groups = <String, List<CourseEntry>>{};
    for (final c in courses) {
      (groups[c.courseName] ??= []).add(c);
    }

    final merged = <CourseEntry>[];
    for (final group in groups.values) {
      if (group.length == 1) {
        merged.add(group.first);
        continue;
      }

      group.sort((a, b) => a.startLesson.compareTo(b.startLesson));

      var current = group.first;
      for (var i = 1; i < group.length; i++) {
        final next = group[i];
        if (next.startLesson <= current.endLesson + 1) {
          // Merge: extend to cover next
          final newEnd = current.endLesson > next.endLesson
              ? current.endLesson
              : next.endLesson;
          current = CourseEntry(
            courseName: current.courseName,
            teacherName: current.teacherName,
            weekday: current.weekday,
            startLesson: current.startLesson,
            endLesson: newEnd,
            weekRange: current.weekRange,
            classroom: current.classroom.isNotEmpty
                ? current.classroom
                : next.classroom,
            campus: current.campus,
            typeSymbol: current.typeSymbol,
          );
        } else {
          merged.add(current);
          current = next;
        }
      }
      merged.add(current);
    }

    return merged;
  }

  /// Deduplicate other-week courses, exclude those already in current week,
  /// and merge adjacent same-name entries.
  static List<CourseEntry> deduplicateBySlot(
    List<CourseEntry> otherCourses,
    List<CourseEntry> currentWeekCourses,
  ) {
    final currentKeys = <String>{};
    for (final c in currentWeekCourses) {
      currentKeys.add('${c.courseName}|${c.startLesson}|${c.endLesson}');
    }

    final seen = <String>{};
    final deduped = otherCourses.where((course) {
      final key =
          '${course.courseName}|${course.startLesson}|${course.endLesson}';
      if (currentKeys.contains(key)) return false;
      return seen.add(key);
    }).toList();

    return mergeAdjacentCourses(deduped);
  }

  Color _colorForCourse(String name, bool isCurrentWeek) {
    final index = name.hashCode.abs() % _courseColors.length;
    return isCurrentWeek ? _courseColors[index] : _inactiveColors[index];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayColumnWidth = (constraints.maxWidth - _slotColumnWidth) / 7;

        return Column(
          children: [
            _DayHeaders(
              slotColumnWidth: _slotColumnWidth,
              dayColumnWidth: dayColumnWidth,
              currentWeek: currentWeek,
              isCurrentWeek: currentWeek == actualCurrentWeek,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SlotColumn(slotColumnWidth: _slotColumnWidth),
                    for (int day = 1; day <= 7; day++)
                      _DayColumn(
                        currentWeekCourses: weekViewModel
                            .coursesForDay(day)
                            .currentWeekCourses,
                        otherWeekCourses: weekViewModel
                            .coursesForDay(day)
                            .otherWeekCourses,
                        colorFor: _colorForCourse,
                        dayColumnWidth: dayColumnWidth,
                        displayWeek: currentWeek,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayHeaders extends StatelessWidget {
  const _DayHeaders({
    required this.slotColumnWidth,
    required this.dayColumnWidth,
    required this.currentWeek,
    required this.isCurrentWeek,
  });

  final double slotColumnWidth;
  final double dayColumnWidth;
  final int currentWeek;
  final bool isCurrentWeek;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = DateTime.now().weekday;
    final weekStartDate = SemesterCalendar.instance.semesterStartDate.value.add(
      Duration(days: (currentWeek - 1) * 7),
    );

    return Container(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: slotColumnWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 4,
                  ),
                  child: Text(
                    '第$currentWeek周',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCurrentWeek ? '本周' : '非本周',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (int i = 0; i < 7; i++)
            Builder(
              builder: (context) {
                final date = weekStartDate.add(Duration(days: i));
                final isToday = isCurrentWeek && (i + 1) == today;

                return SizedBox(
                  width: dayColumnWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isToday
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isToday ? Colors.white : cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '周${'一二三四五六日'[i]}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isToday
                              ? AppColors.primary
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SlotColumn extends StatelessWidget {
  const _SlotColumn({required this.slotColumnWidth});

  final double slotColumnWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (int i = 0; i < 13; i++)
          Container(
            width: slotColumnWidth,
            height: _ScheduleGrid._slotHeight,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ScheduleSlotTimes.slotTimes[i][0],
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.currentWeekCourses,
    required this.otherWeekCourses,
    required this.colorFor,
    required this.dayColumnWidth,
    required this.displayWeek,
  });

  final List<CourseEntry> currentWeekCourses;
  final List<CourseEntry> otherWeekCourses;
  final Color Function(String, bool) colorFor;
  final double dayColumnWidth;
  final int displayWeek;

  @override
  Widget build(BuildContext context) {
    final displayCourses = [
      ...currentWeekCourses.map(
        (course) => _DisplayCourseEntry(course: course, isCurrentWeek: true),
      ),
      ...otherWeekCourses.map(
        (course) => _DisplayCourseEntry(course: course, isCurrentWeek: false),
      ),
    ];

    final placements = _buildCoursePlacements(displayCourses);

    return SizedBox(
      width: dayColumnWidth,
      height: _ScheduleGrid._slotHeight * 13,
      child: Stack(
        children: [
          for (final placement in placements)
            Positioned(
              left: placement.left,
              top:
                  (placement.entry.course.startLesson - 1) *
                  _ScheduleGrid._slotHeight,
              width: placement.width,
              height: _ScheduleGrid._slotHeight * placement.span,
              child: _CourseCell(
                course: placement.entry.course,
                span: placement.span,
                color: colorFor(
                  placement.entry.course.courseName,
                  placement.entry.isCurrentWeek,
                ),
                dayColumnWidth: placement.width,
                isCurrentWeek: placement.entry.isCurrentWeek,
              ),
            ),
        ],
      ),
    );
  }

  List<_PlacedCourse> _buildCoursePlacements(
    List<_DisplayCourseEntry> displayCourses,
  ) {
    if (displayCourses.isEmpty) return const [];

    final sortedCourses = [...displayCourses]
      ..sort((a, b) {
        final byStart = a.course.startLesson.compareTo(b.course.startLesson);
        if (byStart != 0) return byStart;

        if (a.isCurrentWeek != b.isCurrentWeek) {
          return a.isCurrentWeek ? -1 : 1;
        }

        final byEnd = a.course.endLesson.compareTo(b.course.endLesson);
        if (byEnd != 0) return byEnd;

        return a.course.courseName.compareTo(b.course.courseName);
      });

    final placements = <_PlacedCourse>[];
    final clusters = <List<_DisplayCourseEntry>>[];
    var currentCluster = <_DisplayCourseEntry>[];
    var clusterEnd = 0;

    for (final course in sortedCourses) {
      if (currentCluster.isEmpty || course.course.startLesson > clusterEnd) {
        if (currentCluster.isNotEmpty) clusters.add(currentCluster);
        currentCluster = [course];
        clusterEnd = course.course.endLesson;
        continue;
      }

      currentCluster.add(course);
      if (course.course.endLesson > clusterEnd) {
        clusterEnd = course.course.endLesson;
      }
    }

    if (currentCluster.isNotEmpty) clusters.add(currentCluster);

    for (final cluster in clusters) {
      placements.addAll(_buildClusterPlacements(cluster));
    }

    return placements;
  }

  List<_PlacedCourse> _buildClusterPlacements(
    List<_DisplayCourseEntry> cluster,
  ) {
    final currentEntries = cluster
        .where((entry) => entry.isCurrentWeek)
        .toList();
    final otherEntries = cluster
        .where((entry) => !entry.isCurrentWeek)
        .toList();

    if (currentEntries.isNotEmpty) {
      // Current-week courses take full width; hide non-current-week to avoid conflict
      return _buildStandardPlacements(currentEntries, dayColumnWidth);
    }

    // No current-week courses in this slot — show closest non-current-week at full width
    // Only if within 3 weeks of displayed week to avoid clutter
    if (otherEntries.isEmpty) return const [];

    var closest = otherEntries.first;
    var closestDistance = closest.course.weekDistanceTo(displayWeek);
    for (final entry in otherEntries.skip(1)) {
      final distance = entry.course.weekDistanceTo(displayWeek);
      if (distance < closestDistance) {
        closest = entry;
        closestDistance = distance;
      }
    }
    if (closestDistance > 3) return const [];

    return _buildStandardPlacements([closest], dayColumnWidth);
  }

  List<_PlacedCourse> _buildStandardPlacements(
    List<_DisplayCourseEntry> entries,
    double availableWidth,
  ) {
    if (entries.isEmpty) return const [];

    final assignments = _assignColumns(entries);
    final totalColumns = assignments.fold<int>(
      0,
      (maxColumns, assignment) => assignment.column + 1 > maxColumns
          ? assignment.column + 1
          : maxColumns,
    );
    final columnWidth = availableWidth / totalColumns;

    return assignments.map((assignment) {
      final span =
          (assignment.entry.course.endLesson -
                  assignment.entry.course.startLesson +
                  1)
              .clamp(1, 13 - assignment.entry.course.startLesson + 1);

      return _PlacedCourse(
        entry: assignment.entry,
        left: assignment.column * columnWidth,
        width: columnWidth,
        span: span,
      );
    }).toList();
  }

  List<_ColumnAssignment> _assignColumns(List<_DisplayCourseEntry> entries) {
    final assignments = <_ColumnAssignment>[];
    final columnEndLessons = <int>[];

    for (final entry in entries) {
      var targetColumn = -1;

      for (var i = 0; i < columnEndLessons.length; i++) {
        if (columnEndLessons[i] < entry.course.startLesson) {
          targetColumn = i;
          break;
        }
      }

      if (targetColumn == -1) {
        targetColumn = columnEndLessons.length;
        columnEndLessons.add(entry.course.endLesson);
      } else {
        columnEndLessons[targetColumn] = entry.course.endLesson;
      }

      assignments.add(_ColumnAssignment(entry: entry, column: targetColumn));
    }

    return assignments;
  }
}

class _DisplayCourseEntry {
  const _DisplayCourseEntry({
    required this.course,
    required this.isCurrentWeek,
  });

  final CourseEntry course;
  final bool isCurrentWeek;
}

class _ColumnAssignment {
  const _ColumnAssignment({required this.entry, required this.column});

  final _DisplayCourseEntry entry;
  final int column;
}

class _PlacedCourse {
  const _PlacedCourse({
    required this.entry,
    required this.left,
    required this.width,
    required this.span,
  });

  final _DisplayCourseEntry entry;
  final double left;
  final double width;
  final int span;
}

class _CourseCell extends StatelessWidget {
  const _CourseCell({
    required this.course,
    required this.span,
    required this.color,
    required this.dayColumnWidth,
    required this.isCurrentWeek,
  });

  final CourseEntry course;
  final int span;
  final Color color;
  final double dayColumnWidth;
  final bool isCurrentWeek;

  void _showCourseDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                course.courseName,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: Icons.person_outline,
                text:
                    '教师：${course.teacherName.isEmpty ? '待定' : course.teacherName}',
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.meeting_room_outlined,
                text:
                    '教室：${course.classroom.isEmpty ? '待定' : course.classroom}',
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.place_outlined,
                text: '校区：${course.campus.isEmpty ? '待定' : course.campus}',
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.schedule,
                text: '节次：第 ${course.startLesson} - ${course.endLesson} 节',
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.calendar_view_week,
                text: '周次：${course.weekRange}',
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayColor = isCurrentWeek
        ? color.withValues(alpha: isDark ? 0.18 : 0.1)
        : (isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.grey.withValues(alpha: 0.06));
    final cellBackgroundColor = isDark
        ? cs.surfaceContainerHigh
        : cs.surfaceContainerLowest;
    final titleColor = isCurrentWeek
        ? (isDark ? Color.lerp(color, Colors.white, 0.24)! : color)
        : (isDark ? Colors.grey.shade300 : Colors.grey.shade500);
    final metaColor = isCurrentWeek
        ? (isDark
              ? Color.lerp(color, Colors.white, 0.14)!
              : titleColor.withValues(alpha: 0.75))
        : (isDark ? Colors.grey.shade400 : titleColor.withValues(alpha: 0.75));

    return Container(
      width: dayColumnWidth,
      height: _ScheduleGrid._slotHeight * span,
      padding: const EdgeInsets.all(2),
      child: Material(
        color: cellBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _showCourseDetail(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: overlayColor,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 24;
                final dense = constraints.maxHeight < 92;
                final titleFontSize = narrow ? 10.5 : 12.0;
                final metaFontSize = narrow ? 9.0 : 10.0;
                final hasRoom = !narrow && constraints.maxHeight >= 88;
                final hasExtraRoom = hasRoom && constraints.maxHeight >= 120;
                // Reserve lines for metadata; give remaining to title
                final titleLines = constraints.maxHeight >= 180
                    ? (narrow ? 5 : 4)
                    : constraints.maxHeight >= 120
                    ? (narrow ? 3 : 3)
                    : 2;
                final classroomMaxLines = constraints.maxHeight >= 200 ? 4 : 2;
                final teacherMaxLines = constraints.maxHeight >= 160 ? 2 : 1;
                final showWeekTag = !isCurrentWeek && hasExtraRoom;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isCurrentWeek ? color : Colors.grey.shade300,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          narrow ? 2 : 4,
                          6,
                          narrow ? 2 : 4,
                          6,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Text(
                                  course.courseName,
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: titleColor,
                                    height: dense ? 1.1 : 1.18,
                                  ),
                                  maxLines: titleLines,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (hasRoom && course.classroom.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  course.classroom,
                                  style: TextStyle(
                                    fontSize: metaFontSize,
                                    color: metaColor,
                                  ),
                                  maxLines: classroomMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                            if (hasRoom && course.teacherName.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  course.teacherName,
                                  style: TextStyle(
                                    fontSize: metaFontSize,
                                    color: metaColor,
                                  ),
                                  maxLines: teacherMaxLines,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (showWeekTag) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  '非本周',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
