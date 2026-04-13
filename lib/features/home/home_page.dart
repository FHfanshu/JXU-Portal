import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_bootstrap_controller.dart';
import '../../app/theme.dart';
import '../../core/auth/unified_auth.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/semester/semester_calendar.dart';
import '../../core/update/update_checker.dart';
import '../../shared/widgets/login_shell.dart';
import '../../shared/widgets/update_dialog.dart';
import '../campus_card/campus_card_service.dart';
import '../dorm_electricity/dorm_electricity_service.dart';
import '../schedule/schedule_cache_snapshot.dart';
import '../schedule/schedule_model.dart';
import '../schedule/schedule_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _bootstrapController = AppBootstrapController.instance;

  String _campusCardBalance = '--';
  String _dormElectricity = '--';
  CourseEntry? _nextCourse;
  String _nextCourseLabel = '';
  bool _courseLoggedIn = false;
  bool _hasScheduleCache = false;
  DateTime? _scheduleUpdatedAt;
  bool _hasAvailableUpdate = false;
  bool _hasHydratedBootstrapState = false;
  bool _initialLoginPromptChecked = false;

  static const _weekdayLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  int get _currentWeek => SemesterCalendar.instance.weekForDate(DateTime.now());
  bool get _isBootstrapReady =>
      _bootstrapController.phase.value.index >=
      AppBootstrapPhase.localStateReady.index;

  @override
  void initState() {
    super.initState();
    _hasAvailableUpdate = UpdateChecker.instance.availableRelease.value != null;
    SemesterCalendar.instance.semesterStartDate.addListener(
      _onSemesterStartChanged,
    );
    ZhengfangAuth.instance.addListener(_onAcademicAuthChanged);
    _bootstrapController.phase.addListener(_onBootstrapPhaseChanged);
    UpdateChecker.instance.availableRelease.addListener(
      _onAvailableReleaseChanged,
    );
    _onBootstrapPhaseChanged();
  }

  @override
  void dispose() {
    SemesterCalendar.instance.semesterStartDate.removeListener(
      _onSemesterStartChanged,
    );
    ZhengfangAuth.instance.removeListener(_onAcademicAuthChanged);
    _bootstrapController.phase.removeListener(_onBootstrapPhaseChanged);
    UpdateChecker.instance.availableRelease.removeListener(
      _onAvailableReleaseChanged,
    );
    super.dispose();
  }

  void _onAvailableReleaseChanged() {
    if (!mounted) return;
    setState(() {
      _hasAvailableUpdate =
          UpdateChecker.instance.availableRelease.value != null;
    });
  }

  void _onAcademicAuthChanged() {
    if (!mounted || !_isBootstrapReady) return;
    _refreshNextCourse();
  }

  void _onSemesterStartChanged() {
    if (!mounted) return;
    setState(() {});
    if (_isBootstrapReady) {
      _refreshNextCourse();
    }
  }

  void _onBootstrapPhaseChanged() {
    if (!_isBootstrapReady || _hasHydratedBootstrapState) return;
    _hasHydratedBootstrapState = true;
    _applyRestoredState();
    if (mounted) {
      setState(() {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshDeferredContent());
      unawaited(_maybeShowInitialUnifiedAuthPrompt());
    });
  }

  Future<void> _maybeShowInitialUnifiedAuthPrompt() async {
    if (_initialLoginPromptChecked || UnifiedAuthService.instance.isLoggedIn) {
      _initialLoginPromptChecked = true;
      return;
    }

    _initialLoginPromptChecked = true;
    if (!mounted) return;

    await showUnifiedAuthLoginModal(
      context,
      title: '登录一卡通',
      description: '首次使用先完成统一认证，后续可直接进入一卡通与服务大厅',
    );
  }

  int _nextStartLesson(DateTime now) {
    final times = ScheduleSlotTimes.slotTimes;
    for (int i = 0; i < times.length; i++) {
      final parts = times[i][0].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (now.hour < hour || (now.hour == hour && now.minute < minute)) {
        return i + 1;
      }
    }
    return 14;
  }

  int _weekForDate(DateTime date) =>
      SemesterCalendar.instance.weekForDate(date);

  String _labelForDate(DateTime date, DateTime today) {
    final day = DateTime(date.year, date.month, date.day);
    final base = DateTime(today.year, today.month, today.day);
    final delta = day.difference(base).inDays;
    if (delta == 0) return '今天';
    if (delta == 1) return '明天';
    return '${date.month}/${date.day} ${_weekdayLabels[date.weekday - 1]}';
  }

  ({
    bool hasScheduleCache,
    DateTime? scheduleUpdatedAt,
    bool courseLoggedIn,
    CourseEntry? nextCourse,
    String nextCourseLabel,
  })
  _buildNextCourseState({
    required ScheduleCacheSnapshot? snapshot,
    required DateTime now,
  }) {
    final hasScheduleCache = snapshot?.hasData ?? false;
    final today = DateTime(now.year, now.month, now.day);
    final nextLessonToday = _nextStartLesson(now);
    CourseEntry? nextCourse;
    var nextCourseLabel = '';

    if (snapshot != null && snapshot.hasData) {
      for (int offset = 0; offset < 14; offset++) {
        final date = today.add(Duration(days: offset));
        final week = _weekForDate(date);
        final effectiveCourses = ScheduleService.instance
            .buildEffectiveWeekCourses(
              courses: snapshot.courses,
              week: week,
              changeRules: snapshot.changeRules,
            );
        final dayCourses =
            effectiveCourses
                .where((c) => c.weekday == date.weekday)
                .where((c) => offset > 0 || c.startLesson >= nextLessonToday)
                .toList()
              ..sort((a, b) => a.startLesson.compareTo(b.startLesson));
        if (dayCourses.isNotEmpty) {
          nextCourse = dayCourses.first;
          nextCourseLabel = _labelForDate(date, today);
          break;
        }
      }
    }

    return (
      hasScheduleCache: hasScheduleCache,
      scheduleUpdatedAt: snapshot?.lastUpdatedAt,
      courseLoggedIn: ZhengfangAuth.instance.isLoggedIn || hasScheduleCache,
      nextCourse: nextCourse,
      nextCourseLabel: nextCourseLabel,
    );
  }

  void _applyRestoredState() {
    final now = DateTime.now();
    final cachedBalance = CampusCardService.instance.cachedBalance;
    final dormService = DormElectricityService.instance;
    final scheduleSnapshot = ScheduleService.instance.preferredSnapshot(
      termContext: ScheduleService.instance.getCurrentTermContext(now),
    );
    final scheduleState = _buildNextCourseState(
      snapshot: scheduleSnapshot,
      now: now,
    );

    _campusCardBalance = CampusCardService.instance.formatBalance(
      cachedBalance,
    );
    _dormElectricity = dormService.formatElectricity(
      dormService.cachedElectricity,
    );
    _hasScheduleCache = scheduleState.hasScheduleCache;
    _scheduleUpdatedAt = scheduleState.scheduleUpdatedAt;
    _courseLoggedIn = scheduleState.courseLoggedIn;
    _nextCourse = scheduleState.nextCourse;
    _nextCourseLabel = scheduleState.nextCourseLabel;
  }

  Future<void> _refreshDeferredContent() async {
    await _refreshCampusCardBalance();
    await Future.wait<void>([_refreshNextCourse(), _refreshDormElectricity()]);
  }

  Future<void> _refreshNextCourse() async {
    if (!_isBootstrapReady) return;
    try {
      final now = DateTime.now();
      final result = await ScheduleService.instance.loadScheduleSnapshot(
        termContext: ScheduleService.instance.getCurrentTermContext(now),
      );
      if (!mounted) return;

      final scheduleState = _buildNextCourseState(
        snapshot: result.snapshot,
        now: now,
      );

      setState(() {
        _hasScheduleCache = scheduleState.hasScheduleCache;
        _scheduleUpdatedAt = scheduleState.scheduleUpdatedAt;
        _courseLoggedIn = scheduleState.courseLoggedIn;
        _nextCourse = scheduleState.nextCourse;
        _nextCourseLabel = scheduleState.nextCourseLabel;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _courseLoggedIn =
            ZhengfangAuth.instance.isLoggedIn || _hasScheduleCache;
        _nextCourse = null;
        _nextCourseLabel = '';
      });
    }
  }

  Future<void> _refreshCampusCardBalance() async {
    final cached = CampusCardService.instance.cachedBalance;
    if (cached != null && mounted) {
      setState(() {
        _campusCardBalance = CampusCardService.instance.formatBalance(cached);
      });
      return;
    }
    final networkBalance = await CampusCardService.instance.fetchBalance();
    if (!mounted) return;
    setState(() {
      _campusCardBalance = CampusCardService.instance.formatBalance(
        networkBalance,
      );
    });
  }

  Future<void> _refreshDormElectricity() async {
    if (!_isBootstrapReady) return;
    final service = DormElectricityService.instance;
    if (!await service.hasRoomConfig()) {
      if (!mounted) return;
      setState(() {
        _dormElectricity = '--';
      });
      return;
    }
    final value = await service.fetchElectricity();
    if (!mounted) return;
    setState(() {
      _dormElectricity = service.formatElectricity(value);
    });
  }

  Future<void> _openSchedule(BuildContext context) async {
    await context.pushNamed('schedule');
    if (!mounted) return;
    _refreshNextCourse();
  }

  String _formatScheduleUpdatedAt(DateTime? value) {
    if (value == null) return '未缓存';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  Widget _buildHeaderScheduleStatus(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final value = _hasScheduleCache
        ? '课表更新于${_formatScheduleUpdatedAt(_scheduleUpdatedAt)}'
        : '未更新';

    final active = _hasScheduleCache;
    final background = isDark
        ? (active
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.06))
        : (active
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.05));
    final border = isDark
        ? (active
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.1))
        : (active
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.primary.withValues(alpha: 0.08));
    final textColor = isDark
        ? Colors.white.withValues(alpha: active ? 0.92 : 0.72)
        : AppColors.primary.withValues(alpha: active ? 0.9 : 0.62);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildHeaderScheduleStatus(context),
                ),
              ),
              const SizedBox(height: 8),
              _buildHeader(context),
              const SizedBox(height: 16),
              // Two-column staggered waterfall layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        children: [
                          _buildCampusCardBalance(context),
                          const SizedBox(height: 10),
                          _buildDormElectricityCard(context),
                          const SizedBox(height: 10),
                          _buildLearningServicesCard(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right column
                    Expanded(
                      child: Column(
                        children: [
                          _buildNoticeCard(context),
                          const SizedBox(height: 10),
                          _buildGradesCard(context),
                          const SizedBox(height: 10),
                          _buildDormServicesCard(context),
                          const SizedBox(height: 10),
                          _buildMoreServicesCard(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: GestureDetector(
        onTap: () => _openSchedule(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7B1527),
                  AppColors.primary,
                  Color(0xFFB7485E),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: -40,
                  bottom: -48,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: -30,
                  top: -20,
                  child: Opacity(
                    opacity: 0.12,
                    child: SvgPicture.asset(
                      'assets/header_texture.svg',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: label + week + action icons
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '第 $_currentWeek 周',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '下节课',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_hasAvailableUpdate) ...[
                            _buildUpdateAction(context),
                            const SizedBox(width: 12),
                          ],
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: () => context.pushNamed('notice-list'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Course content + action on the same bottom line
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _buildCourseContent(context)),
                          const SizedBox(width: 8),
                          Text(
                            '查看课表 →',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateAction(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.system_update_outlined,
            color: Colors.white,
            size: 22,
          ),
          onPressed: () {
            final release = UpdateChecker.instance.availableRelease.value;
            if (release == null) return;
            showUpdateDialog(context, release);
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: '发现新版本',
        ),
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseContent(BuildContext context) {
    if (!_courseLoggedIn) {
      return Text(
        '登录后查看课程',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    if (_nextCourse == null) {
      return Text(
        '近期无课',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    final course = _nextCourse!;
    final time = ScheduleSlotTimes.timeRange(
      course.startLesson,
      course.endLesson,
    );
    final whenText = _nextCourseLabel.isEmpty
        ? time
        : '$_nextCourseLabel $time';
    final campus = course.campus.trim();
    final classroom = course.classroom.trim();
    final location = (campus.isEmpty && classroom.isEmpty)
        ? '地点待定'
        : (campus.isEmpty
              ? classroom
              : (classroom.isEmpty ? campus : '$campus $classroom'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.translate(
          offset: const Offset(-2, -4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Text(
              course.courseName,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              Icons.schedule,
              size: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              whenText,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '第 ${course.startLesson}-${course.endLesson} 节',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                location,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCampusCardBalance(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          await context.pushNamed('campus-card');
          if (!mounted) return;
          _refreshCampusCardBalance();
        },
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? cs.outline.withValues(alpha: 0.3)
                  : cs.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '校园卡',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _campusCardBalance == '--'
                        ? Text(
                            '余额未刷新，请先登录一卡通',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _campusCardBalance,
                                style: TextStyle(
                                  fontSize: 32,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '元',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await context.pushNamed('campus-card-payment');
                      if (!mounted) return;
                      _refreshCampusCardBalance();
                    },
                    child: Transform.translate(
                      offset: const Offset(-4, 0),
                      child: IntrinsicWidth(
                        child: Container(
                          height: 44,
                          constraints: const BoxConstraints(minWidth: 80),
                          padding: const EdgeInsets.only(left: 12, right: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 28,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '付款码',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                      height: 1.0,
                                    ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2, bottom: 4),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDormElectricityCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return GestureDetector(
      onTap: () async {
        await context.pushNamed('dorm-electricity');
        if (!mounted) return;
        await _refreshDormElectricity();
      },
      child: Container(
        height: 136,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? cs.outline.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.bolt_outlined,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '宿舍电费',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          '剩余 $_dormElectricity 度',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 寝室服务卡片
  Widget _buildDormServicesCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return GestureDetector(
      onTap: () => context.pushNamed(
        'news-detail',
        extra: {
          'title': '寝室服务',
          'url': 'http://jdhq.wap.zjxu.edu.cn/Base/Center/center/account_id/6',
        },
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? cs.outline.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.home_outlined,
                color: AppColors.success,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '寝室服务',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningServicesCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? cs.outline.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习服务',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              _buildLearningServiceItem(
                context,
                Icons.workspace_premium_outlined,
                '第二课堂',
                AppColors.gold,
                onTap: () {
                  context.pushNamed('second-classroom');
                },
              ),
              const SizedBox(height: 8),
              _buildLearningServiceItem(
                context,
                Icons.local_library_outlined,
                '图书馆',
                AppColors.info,
                onTap: () {
                  context.pushNamed('library');
                },
              ),
              const SizedBox(height: 8),
              _buildChangxingJiadaTile(context),
              const SizedBox(height: 8),
              _buildLearningServiceItem(
                context,
                Icons.science_outlined,
                '实践通知',
                const Color(0xFF1976D2),
                onTap: () {
                  context.pushNamed('sjjx-notice-list');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningServiceItem(
    BuildContext context,
    IconData icon,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: cs.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangxingJiadaTile(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = const Color(0xFF2EA567);
    final tileBgColor = isDark
        ? tileColor.withValues(alpha: 0.08)
        : const Color(0xFFF3FAF5);
    return InkWell(
      onTap: () async {
        await context.pushNamed('changxing-jiada');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: tileBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tileColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.north_rounded, color: tileColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '畅行嘉大',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return GestureDetector(
      onTap: () => context.pushNamed('notice-list'),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? cs.outline.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: AppColors.gold,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '校园公告',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildGradesCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return GestureDetector(
      onTap: () => context.pushNamed('grades'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? cs.outline.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school_outlined,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '成绩查询',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '查看各科成绩与绩点',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreServicesCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? cs.surfaceContainerLowest : Colors.white;

    return GestureDetector(
      onTap: () async {
        await context.pushNamed('service-hall');
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? cs.outline.withValues(alpha: 0.3)
                : cs.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.apps_rounded, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '更多服务',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
