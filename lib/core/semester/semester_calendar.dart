import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SemesterCalendar {
  SemesterCalendar._();

  static final SemesterCalendar instance = SemesterCalendar._();

  static const _keySemesterStartDate = 'semester_start_date_millis';
  static const _defaultStartMonth = 3;
  static const _defaultStartDay = 2;

  final ValueNotifier<DateTime> semesterStartDate = ValueNotifier<DateTime>(
    _defaultSemesterStart(DateTime.now()),
  );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMillis = prefs.getInt(_keySemesterStartDate);
    if (storedMillis == null) {
      semesterStartDate.value = _defaultSemesterStart(DateTime.now());
      return;
    }
    semesterStartDate.value = _normalize(
      DateTime.fromMillisecondsSinceEpoch(storedMillis),
    );
  }

  Future<void> setSemesterStartDate(DateTime date) async {
    final normalized = _normalize(date);
    semesterStartDate.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _keySemesterStartDate,
      normalized.millisecondsSinceEpoch,
    );
  }

  Future<void> resetSemesterStartDate() async {
    final defaultDate = _defaultSemesterStart(DateTime.now());
    semesterStartDate.value = defaultDate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySemesterStartDate);
  }

  int weekForDate(DateTime date) {
    final day = _normalize(date);
    final diff = day.difference(semesterStartDate.value).inDays;
    return ((diff ~/ 7) + 1).clamp(1, 20);
  }

  static DateTime _defaultSemesterStart(DateTime now) {
    return DateTime(now.year, _defaultStartMonth, _defaultStartDay);
  }

  static DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
