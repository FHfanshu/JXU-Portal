import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/core/semester/semester_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('normalizes stored start date and persists manual changes', () async {
    final calendar = SemesterCalendar.instance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'semester_start_date_millis',
      DateTime(2026, 3, 1, 14, 30).millisecondsSinceEpoch,
    );

    await calendar.init();
    expect(calendar.semesterStartDate.value, DateTime(2026, 3, 1));

    await calendar.setSemesterStartDate(DateTime(2026, 3, 8, 23, 59));
    expect(calendar.semesterStartDate.value, DateTime(2026, 3, 8));
    expect(
      prefs.getInt('semester_start_date_millis'),
      DateTime(2026, 3, 8).millisecondsSinceEpoch,
    );
  });

  test('weekForDate clamps within 1 to 20', () async {
    final calendar = SemesterCalendar.instance;
    await calendar.setSemesterStartDate(DateTime(2026, 3, 2));

    expect(calendar.weekForDate(DateTime(2026, 2, 20)), 1);
    expect(calendar.weekForDate(DateTime(2026, 3, 2, 23, 59)), 1);
    expect(calendar.weekForDate(DateTime(2026, 3, 9)), 2);
    expect(calendar.weekForDate(DateTime(2026, 8, 30)), 20);
  });
}
