import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/zhengfang_auth.dart';
import '../../core/network/dio_client.dart';
import '../../core/semester/semester_calendar.dart';
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

class ScheduleService {
  ScheduleService._();

  static final ScheduleService instance = ScheduleService._();

  static const scheduleRefreshWindow = Duration(days: 7);
  static const changeRuleRefreshWindow = Duration(days: 1);
  static const _cacheStorageKey = 'zjxu_schedule_cache_snapshots_v1';
  static const _lastStudentStorageKey = 'zjxu_schedule_last_student_id_v1';

  final Map<String, ScheduleCacheSnapshot> _snapshots = {};
  final Map<String, Future<ScheduleLoadResult>> _inflightLoads = {};

  SharedPreferences? _prefs;
  bool _restored = false;
  String? _lastStudentId;

  Dio get _dio => DioClient.instance.dio;

  int getCurrentWeek() {
    return SemesterCalendar.instance.weekForDate(DateTime.now());
  }

  ScheduleTermContext getCurrentTermContext([DateTime? now]) {
    return ScheduleTermContext.current(now);
  }

  String? get preferredStudentId {
    return _resolveStudentId();
  }

  Future<void> restoreCache() async {
    _prefs = await SharedPreferences.getInstance();
    _snapshots.clear();

    final raw = _prefs!.getString(_cacheStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is Map<String, dynamic>) {
              _snapshots[entry.key] = ScheduleCacheSnapshot.fromJson(value);
            }
          }
        }
      } catch (_) {
        _snapshots.clear();
      }
    }

    _lastStudentId =
        _prefs!.getString(_lastStudentStorageKey) ?? _deriveLastStudentId();
    _restored = true;
  }

  ScheduleCacheSnapshot? preferredSnapshot({
    ScheduleTermContext? termContext,
    String? studentId,
  }) {
    final resolvedStudentId = _resolveStudentId(studentId);
    if (resolvedStudentId == null || resolvedStudentId.isEmpty) return null;
    final context = termContext ?? getCurrentTermContext();
    return _snapshots[_cacheKeyFor(resolvedStudentId, context)];
  }

  Future<ScheduleLoadResult> loadScheduleSnapshot({
    ScheduleTermContext? termContext,
    String? studentId,
    bool forceRefresh = false,
  }) async {
    await _ensureRestored();

    final context = termContext ?? getCurrentTermContext();
    final resolvedStudentId = _resolveStudentId(studentId);
    if (resolvedStudentId == null || resolvedStudentId.isEmpty) {
      return const ScheduleLoadResult(requiresLogin: true, message: '请先登录教务系统');
    }

    final cacheKey = _cacheKeyFor(resolvedStudentId, context);
    final cachedSnapshot =
        _snapshots[cacheKey] ??
        ScheduleCacheSnapshot.empty(
          studentId: resolvedStudentId,
          termContext: context,
        );

    final now = DateTime.now();
    final shouldRefreshSchedule =
        forceRefresh ||
        cachedSnapshot.needsScheduleRefresh(now, maxAge: scheduleRefreshWindow);
    final shouldRefreshChangeRules =
        forceRefresh ||
        cachedSnapshot.needsChangeRulesRefresh(
          now,
          maxAge: changeRuleRefreshWindow,
        );
    final needsRefresh = shouldRefreshSchedule || shouldRefreshChangeRules;

    if (!needsRefresh) {
      return ScheduleLoadResult(
        snapshot: cachedSnapshot.hasData ? cachedSnapshot : null,
        usedCache: cachedSnapshot.hasData,
      );
    }

    final canRefresh =
        ZhengfangAuth.instance.isLoggedIn &&
        ZhengfangAuth.instance.currentStudentId == resolvedStudentId;
    if (!canRefresh) {
      if (cachedSnapshot.hasData) {
        return ScheduleLoadResult(
          snapshot: cachedSnapshot,
          requiresLogin: true,
          usedCache: true,
          message: '显示的是本地缓存课表，刷新需要重新登录教务',
        );
      }
      return const ScheduleLoadResult(requiresLogin: true, message: '请先登录教务系统');
    }

    return _loadOrJoin(
      cacheKey,
      () => _refreshSnapshot(
        existingSnapshot: cachedSnapshot,
        studentId: resolvedStudentId,
        termContext: context,
        refreshSchedule: shouldRefreshSchedule,
        refreshChangeRules: shouldRefreshChangeRules,
      ),
    );
  }

  Future<List<CourseEntry>> fetchSchedule(
    String studentId,
    int year,
    int term,
  ) async {
    await DioClient.instance.ensureInitialized();
    final referer = ZhengfangAuth.instance.buildPortalUrl(
      '/kbcx/xskbcx_cxXskbcxIndex.html',
      queryParameters: {
        'gnmkdm': 'N2151',
        'layout': 'default',
        'su': studentId,
      },
    );

    final resp = await _dio.post<dynamic>(
      '/kbcx/xskbcx_cxXsKb.html',
      queryParameters: {'gnmkdm': 'N2151', 'su': studentId},
      data: 'xnm=$year&xqm=$term&kzlx=ck',
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        validateStatus: (status) => status != null && status < 1000,
        headers: {'Referer': referer, 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );

    final statusCode = resp.statusCode ?? 0;
    if (statusCode == 901 || statusCode == 302 || statusCode == 303) {
      throw const ScheduleAuthExpiredException();
    }
    if (statusCode >= 400) {
      throw ScheduleRequestException('课表接口异常（状态码：$statusCode）');
    }

    final data = resp.data;
    if (data is! Map<String, dynamic>) {
      final raw = data?.toString() ?? '';
      if (_looksLikeLoginExpired(raw)) {
        throw const ScheduleAuthExpiredException();
      }
      throw const ScheduleRequestException('课表返回数据格式异常');
    }

    final message = data['message']?.toString() ?? '';
    if (_looksLikeLoginExpired(message)) {
      throw const ScheduleAuthExpiredException();
    }

    final kbList = data['kbList'] as List<dynamic>? ?? [];
    return kbList
        .whereType<Map<String, dynamic>>()
        .map(CourseEntry.fromJson)
        .toList();
  }

  Future<List<CourseChangeRule>> fetchCourseChangeRules(
    String studentId,
  ) async {
    await DioClient.instance.ensureInitialized();
    final messages = <String>{};
    messages.addAll(await _fetchInboxChangeMessages());

    final referer = ZhengfangAuth.instance.academicServiceUrl;
    final resp = await _dio.post<String>(
      '/xtgl/index_cxAreaThree.html',
      queryParameters: {
        'localeKey': 'zh_CN',
        'gnmkdm': 'index',
        'su': studentId,
      },
      options: Options(
        responseType: ResponseType.plain,
        contentType: 'application/x-www-form-urlencoded;charset=UTF-8',
        validateStatus: (status) => status != null && status < 1000,
        headers: {'Referer': referer, 'X-Requested-With': 'XMLHttpRequest'},
      ),
    );

    final statusCode = resp.statusCode ?? 0;
    if (statusCode == 901 || statusCode == 302 || statusCode == 303) {
      throw const ScheduleAuthExpiredException();
    }
    if (statusCode >= 400) {
      throw ScheduleRequestException('课表调停课接口异常（状态码：$statusCode）');
    }

    final html = resp.data ?? '';
    if (_looksLikeLoginExpired(html)) {
      throw const ScheduleAuthExpiredException();
    }

    messages.addAll(_extractAreaThreeMessages(html));
    return parseCourseChangeMessages(messages);
  }

  Future<List<String>> _fetchInboxChangeMessages() async {
    await DioClient.instance.ensureInitialized();
    final resp = await _dio.post<dynamic>(
      '/xtgl/index_cxDbsy.html',
      queryParameters: {'flag': '1'},
      options: Options(
        validateStatus: (status) => status != null && status < 1000,
        headers: {
          'Referer': ZhengfangAuth.instance.academicServiceUrl,
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    final statusCode = resp.statusCode ?? 0;
    if (statusCode == 901 || statusCode == 302 || statusCode == 303) {
      throw const ScheduleAuthExpiredException();
    }
    if (statusCode >= 400) {
      throw ScheduleRequestException('教学消息接口异常（状态码：$statusCode）');
    }

    final data = resp.data;
    if (data is! Map<String, dynamic>) {
      final raw = data?.toString() ?? '';
      if (_looksLikeLoginExpired(raw)) {
        throw const ScheduleAuthExpiredException();
      }
      return const [];
    }

    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              item['TKXX']?.toString() ??
              item['XXNR']?.toString() ??
              item['XXBT']?.toString() ??
              '',
        )
        .map((message) => _decodeHtmlEntities(message).trim())
        .where((message) => message.isNotEmpty)
        .toList();
  }

  List<CourseChangeRule> parseCourseChangeMessages(Iterable<String> messages) {
    final rules = <CourseChangeRule>[];
    final seen = <String>{};

    for (final rawMessage in messages) {
      final message = rawMessage.trim();
      if (!message.contains('调课提醒') &&
          !message.contains('停课提醒') &&
          !message.contains('补课提醒')) {
        continue;
      }

      final rule = _parseCourseChangeRule(message);
      if (rule == null || !seen.add(rule.signature)) continue;
      rules.add(rule);
    }

    return rules;
  }

  CourseChangeRule? _parseCourseChangeRule(String message) {
    final lessons = _extractLessonInfos(message);
    final courseName = _extractCourseName(message);

    if (message.contains('调课提醒')) {
      final originalLesson = lessons.isNotEmpty ? lessons.first : null;
      final targetLesson = lessons.length > 1 ? lessons[1] : null;
      if (originalLesson == null) return null;

      return CourseChangeRule(
        type: targetLesson == null
            ? CourseChangeType.cancel
            : CourseChangeType.reschedule,
        originalLesson: originalLesson,
        targetLesson: targetLesson,
        courseName: courseName,
        teacherName:
            _extractAdjustedTeacherName(message) ??
            _extractTeacherName(message),
        classroom: _extractAdjustedClassroom(message),
      );
    }

    if (message.contains('停课提醒')) {
      final originalLesson = lessons.isNotEmpty ? lessons.first : null;
      if (originalLesson == null) return null;

      return CourseChangeRule(
        type: CourseChangeType.cancel,
        originalLesson: originalLesson,
        courseName: courseName,
      );
    }

    if (message.contains('补课提醒')) {
      final targetLesson = lessons.isNotEmpty ? lessons.first : null;
      if (targetLesson == null) return null;

      return CourseChangeRule(
        type: CourseChangeType.makeup,
        targetLesson: targetLesson,
        courseName: courseName,
        teacherName: _extractTeacherName(message),
        classroom: _extractAdjustedClassroom(message),
      );
    }

    return null;
  }

  List<CourseLessonSlot> _extractLessonInfos(String message) {
    final slots = <CourseLessonSlot>[];
    final pattern = RegExp(
      r'第\s*(\d+)\s*周\s*星期([一二三四五六日天])\s*第\s*(\d+)(?:\s*[-~]\s*(\d+))?\s*节',
    );

    for (final match in pattern.allMatches(message)) {
      final week = int.tryParse(match.group(1) ?? '');
      final weekday = _weekdayToInt(match.group(2) ?? '');
      final startLesson = int.tryParse(match.group(3) ?? '');
      final endLesson = int.tryParse(match.group(4) ?? match.group(3) ?? '');
      if (week == null ||
          weekday == null ||
          startLesson == null ||
          endLesson == null) {
        continue;
      }

      slots.add(
        CourseLessonSlot(
          week: week,
          weekday: weekday,
          startLesson: startLesson,
          endLesson: endLesson,
        ),
      );
    }

    return slots;
  }

  String? _extractCourseName(String message) {
    final patterns = [
      RegExp(r'上的(.+?)课程调课'),
      RegExp(r'对课程(.+?)进行停课'),
      RegExp(r'上的(.+?)课程停课'),
      RegExp(r'对课程(.+?)进行补课'),
      RegExp(r'上的(.+?)课程进行补课'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      final name = match?.group(1)?.trim() ?? '';
      if (name.isNotEmpty) return name;
    }

    return null;
  }

  String? _extractTeacherName(String message) {
    final match = RegExp(
      r'(?:调课提醒|补课提醒|停课提醒)[:：]?\s*(?:原定)?(.+?)老师',
    ).firstMatch(message);
    final name = match?.group(1)?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  String? _extractAdjustedTeacherName(String message) {
    final match = RegExp(r'调课到由(.+?)老师').firstMatch(message);
    final name = match?.group(1)?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  String? _extractAdjustedClassroom(String message) {
    final segment = message.contains('调课到')
        ? message.split('调课到').last
        : message;
    final match = RegExp(
      r'第\s*\d+\s*周\s*星期[一二三四五六日天]\s*第\s*\d+(?:\s*[-~]\s*\d+)?\s*节(?:在|于)(.+?)上',
    ).firstMatch(segment);
    final classroom = match?.group(1)?.trim() ?? '';
    return classroom.isEmpty ? null : classroom;
  }

  List<String> _extractAreaThreeMessages(String html) {
    final messages = <String>[];
    final messagePattern = RegExp(r'data-tkxx="([^"]+)"');

    for (final match in messagePattern.allMatches(html)) {
      final encodedMessage = match.group(1) ?? '';
      final message = _decodeHtmlEntities(encodedMessage).trim();
      if (message.isNotEmpty) messages.add(message);
    }

    return messages;
  }

  List<CourseEntry> buildEffectiveWeekCourses({
    required List<CourseEntry> courses,
    required int week,
    List<CourseChangeRule> changeRules = const [],
  }) {
    final effectiveCourses = courses
        .where((course) => course.isInWeek(week))
        .where(
          (course) =>
              !changeRules.any((rule) => rule.removesCourse(course, week)),
        )
        .toList();

    for (final rule in changeRules.where(
      (rule) => rule.addsCourseToWeek(week),
    )) {
      final syntheticCourse = _buildSyntheticCourse(
        rule: rule,
        week: week,
        courses: courses,
      );
      if (syntheticCourse != null) {
        effectiveCourses.add(syntheticCourse);
      }
    }

    final deduped = <CourseEntry>[];
    final seen = <String>{};
    for (final course in effectiveCourses) {
      final signature = [
        course.courseName,
        course.teacherName,
        course.weekday,
        course.startLesson,
        course.endLesson,
        course.classroom,
        course.weekRange,
      ].join('|');
      if (seen.add(signature)) {
        deduped.add(course);
      }
    }

    return deduped;
  }

  CourseEntry? _buildSyntheticCourse({
    required CourseChangeRule rule,
    required int week,
    required List<CourseEntry> courses,
  }) {
    final targetLesson = rule.targetLesson;
    if (targetLesson == null || targetLesson.week != week) return null;

    final template = _findTemplateCourse(rule, courses);
    final courseName = (rule.courseName?.trim().isNotEmpty ?? false)
        ? rule.courseName!.trim()
        : template?.courseName ?? '调课课程';
    final teacherName = (rule.teacherName?.trim().isNotEmpty ?? false)
        ? rule.teacherName!.trim()
        : template?.teacherName ?? '';
    final classroom = (rule.classroom?.trim().isNotEmpty ?? false)
        ? rule.classroom!.trim()
        : template?.classroom ?? '';

    return CourseEntry(
      courseName: courseName,
      teacherName: teacherName,
      weekday: targetLesson.weekday,
      startLesson: targetLesson.startLesson,
      endLesson: targetLesson.endLesson,
      weekRange: '$week周',
      classroom: classroom,
      campus: template?.campus ?? '',
      typeSymbol: template?.typeSymbol ?? '',
    );
  }

  CourseEntry? _findTemplateCourse(
    CourseChangeRule rule,
    List<CourseEntry> courses,
  ) {
    final lesson = rule.originalLesson;
    final ruleCourseName = rule.courseName?.trim() ?? '';

    if (lesson != null) {
      for (final course in courses) {
        if (!course.isInWeek(lesson.week) || !lesson.overlaps(course)) {
          continue;
        }
        if (ruleCourseName.isEmpty ||
            _matchesCourseName(course.courseName, ruleCourseName)) {
          return course;
        }
      }
    }

    if (ruleCourseName.isNotEmpty) {
      for (final course in courses) {
        if (_matchesCourseName(course.courseName, ruleCourseName)) {
          return course;
        }
      }
    }

    return null;
  }

  @visibleForTesting
  Future<void> debugClearCache() async {
    await _ensureRestored();
    _snapshots.clear();
    _lastStudentId = null;
    _restored = true;
    await _prefs?.remove(_cacheStorageKey);
    await _prefs?.remove(_lastStudentStorageKey);
  }

  @visibleForTesting
  void debugSetSnapshot(ScheduleCacheSnapshot snapshot) {
    _snapshots[_cacheKeyFor(snapshot.studentId, snapshot.termContext)] =
        snapshot;
    _lastStudentId = snapshot.studentId;
    _restored = true;
  }

  Future<void> _ensureRestored() async {
    if (_restored) return;
    await restoreCache();
  }

  Future<ScheduleLoadResult> _loadOrJoin(
    String key,
    Future<ScheduleLoadResult> Function() loader,
  ) {
    final existing = _inflightLoads[key];
    if (existing != null) return existing;

    final future = loader();
    _inflightLoads[key] = future;
    future.whenComplete(() => _inflightLoads.remove(key));
    return future;
  }

  Future<ScheduleLoadResult> _refreshSnapshot({
    required ScheduleCacheSnapshot existingSnapshot,
    required String studentId,
    required ScheduleTermContext termContext,
    required bool refreshSchedule,
    required bool refreshChangeRules,
  }) async {
    var nextSnapshot = existingSnapshot;
    var didRefresh = false;
    final warnings = <String>[];

    if (refreshSchedule) {
      try {
        final courses = await fetchSchedule(
          studentId,
          termContext.academicYear,
          termContext.term,
        );
        nextSnapshot = nextSnapshot.copyWith(
          courses: courses,
          scheduleUpdatedAt: DateTime.now(),
        );
        didRefresh = true;
      } on ScheduleAuthExpiredException {
        ZhengfangAuth.instance.markLoggedOut();
        return _buildAuthExpiredResult(existingSnapshot, nextSnapshot);
      } on ScheduleRequestException catch (error) {
        if (!existingSnapshot.hasData) {
          return ScheduleLoadResult(message: error.message);
        }
        warnings.add('课表刷新失败，显示的是缓存数据');
      } on DioException catch (error) {
        if (!existingSnapshot.hasData) {
          final code = error.response?.statusCode;
          return ScheduleLoadResult(
            message: code == null ? '网络请求失败，请稍后重试' : '网络请求失败（状态码：$code）',
          );
        }
        warnings.add('课表刷新失败，显示的是缓存数据');
      } catch (_) {
        if (!existingSnapshot.hasData) {
          return const ScheduleLoadResult(message: '获取课表失败，请稍后重试');
        }
        warnings.add('课表刷新失败，显示的是缓存数据');
      }
    }

    final shouldLoadChangeRules =
        refreshChangeRules && nextSnapshot.courses.isNotEmpty;
    if (shouldLoadChangeRules) {
      try {
        final changeRules = await fetchCourseChangeRules(studentId);
        nextSnapshot = nextSnapshot.copyWith(
          changeRules: changeRules,
          changeRulesUpdatedAt: DateTime.now(),
        );
        didRefresh = true;
      } on ScheduleAuthExpiredException {
        ZhengfangAuth.instance.markLoggedOut();
        if (didRefresh) {
          await _persistSnapshot(nextSnapshot);
        }
        return ScheduleLoadResult(
          snapshot: nextSnapshot.hasData ? nextSnapshot : existingSnapshot,
          requiresLogin: true,
          usedCache: (nextSnapshot.hasData || existingSnapshot.hasData),
          didRefresh: didRefresh,
          message: '教务登录已过期，调课提醒继续使用缓存',
        );
      } on ScheduleRequestException {
        warnings.add('调课提醒刷新失败，继续使用缓存');
      } on DioException {
        warnings.add('调课提醒刷新失败，继续使用缓存');
      } catch (_) {
        warnings.add('调课提醒刷新失败，继续使用缓存');
      }
    }

    if (didRefresh) {
      await _persistSnapshot(nextSnapshot);
    }

    final snapshot = nextSnapshot.hasData
        ? nextSnapshot
        : (existingSnapshot.hasData ? existingSnapshot : null);
    return ScheduleLoadResult(
      snapshot: snapshot,
      message: warnings.isEmpty ? null : warnings.join('，'),
      usedCache: existingSnapshot.hasData,
      didRefresh: didRefresh,
    );
  }

  ScheduleLoadResult _buildAuthExpiredResult(
    ScheduleCacheSnapshot existingSnapshot,
    ScheduleCacheSnapshot updatedSnapshot,
  ) {
    final snapshot = updatedSnapshot.hasData
        ? updatedSnapshot
        : (existingSnapshot.hasData ? existingSnapshot : null);

    if (snapshot != null) {
      return ScheduleLoadResult(
        snapshot: snapshot,
        requiresLogin: true,
        usedCache: true,
        message: '教务登录已过期，显示的是本地缓存课表',
      );
    }

    return const ScheduleLoadResult(
      requiresLogin: true,
      message: '教务登录已过期，请重新登录',
    );
  }

  Future<void> _persistSnapshot(ScheduleCacheSnapshot snapshot) async {
    await _ensureRestored();
    _snapshots[_cacheKeyFor(snapshot.studentId, snapshot.termContext)] =
        snapshot;
    _lastStudentId = snapshot.studentId;

    final encoded = jsonEncode(
      _snapshots.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs?.setString(_cacheStorageKey, encoded);
    await _prefs?.setString(_lastStudentStorageKey, snapshot.studentId);
  }

  String? _resolveStudentId([String? studentId]) {
    final explicit = studentId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final current = ZhengfangAuth.instance.currentStudentId?.trim();
    if (current != null && current.isNotEmpty) return current;

    final cached = _lastStudentId?.trim();
    if (cached != null && cached.isNotEmpty) return cached;

    return null;
  }

  String _cacheKeyFor(String studentId, ScheduleTermContext termContext) {
    return '$studentId|${termContext.academicYear}|${termContext.term}';
  }

  String? _deriveLastStudentId() {
    final snapshots = _snapshots.values.toList()
      ..sort((left, right) {
        final leftAt = left.lastUpdatedAt?.millisecondsSinceEpoch ?? 0;
        final rightAt = right.lastUpdatedAt?.millisecondsSinceEpoch ?? 0;
        return rightAt.compareTo(leftAt);
      });
    return snapshots.isEmpty ? null : snapshots.first.studentId;
  }

  int? _weekdayToInt(String text) {
    return switch (text) {
      '一' => 1,
      '二' => 2,
      '三' => 3,
      '四' => 4,
      '五' => 5,
      '六' => 6,
      '日' || '天' => 7,
      _ => null,
    };
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  bool _looksLikeLoginExpired(String text) {
    final value = text.toLowerCase();
    return value.contains('登录') ||
        value.contains('登陆') ||
        value.contains('session') ||
        value.contains('expired') ||
        value.contains('请先登录') ||
        value.contains('重新登录');
  }

  bool _matchesCourseName(String left, String right) {
    final a = normalizeCourseName(left);
    final b = normalizeCourseName(right);
    if (a.isEmpty || b.isEmpty) return false;
    return a.contains(b) || b.contains(a);
  }
}
