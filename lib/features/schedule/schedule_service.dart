/// Stub implementation for open source release.
/// Real schedule fetching implementation is not included.
/// 
/// This file provides type definitions and stub implementations
/// to allow the UI code to compile without the actual service logic.

import 'package:flutter/foundation.dart';

import 'schedule_cache_snapshot.dart';
import 'schedule_change_rule.dart';
import 'schedule_model.dart';
import 'schedule_term_context.dart';

export 'schedule_change_rule.dart';

class ScheduleRequestException implements Exception {
  const ScheduleRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ScheduleAuthExpiredException extends ScheduleRequestException {
  const ScheduleAuthExpiredException() : super('登录状态已过期，请重新登录');
}

class ScheduleLoadResult {
  const ScheduleLoadResult({
    this.snapshot,
    this.message,
    this.requiresLogin = false,
    this.usedCache = false,
    this.didRefresh = false,
  });

  final ScheduleCacheSnapshot? snapshot;
  final String? message;
  final bool requiresLogin;
  final bool usedCache;
  final bool didRefresh;

  bool get hasData => snapshot?.hasData ?? false;
}

/// Stub service - schedule fetching logic not included in open source
class ScheduleService {
  ScheduleService._();
  static final ScheduleService instance = ScheduleService._();

  static const scheduleRefreshWindow = Duration(days: 7);
  static const changeRuleRefreshWindow = Duration(days: 1);

  int getCurrentWeek() {
    // Stub - return default value
    return 1;
  }

  ScheduleTermContext getCurrentTermContext([DateTime? now]) {
    return ScheduleTermContext.current(now);
  }

  String? get preferredStudentId => null;

  Future<void> restoreCache() async {
    // Stub - not implemented
  }

  ScheduleCacheSnapshot? preferredSnapshot({
    ScheduleTermContext? termContext,
    String? studentId,
  }) {
    // Stub - not implemented
    return null;
  }

  Future<ScheduleLoadResult> loadScheduleSnapshot({
    ScheduleTermContext? termContext,
    String? studentId,
    bool forceRefresh = false,
  }) async {
    // Stub - not implemented
    return const ScheduleLoadResult(requiresLogin: true, message: '请先登录教务系统');
  }

  Future<List<CourseEntry>> fetchSchedule(
    String studentId,
    int year,
    int term,
  ) async {
    // Stub - not implemented
    return [];
  }

  Future<List<CourseChangeRule>> fetchCourseChangeRules(String studentId) async {
    // Stub - not implemented
    return [];
  }

  List<CourseChangeRule> parseCourseChangeMessages(Iterable<String> messages) {
    // Stub - not implemented
    return [];
  }

  List<CourseEntry> buildEffectiveWeekCourses({
    required List<CourseEntry> courses,
    required int week,
    List<CourseChangeRule> changeRules = const [],
  }) {
    // Stub - return original courses
    return courses.where((course) => course.isInWeek(week)).toList();
  }

  @visibleForTesting
  Future<void> debugClearCache() async {
    // Stub - not implemented
  }

  @visibleForTesting
  void debugSetSnapshot(ScheduleCacheSnapshot snapshot) {
    // Stub - not implemented
  }
}