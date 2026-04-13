import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/dorm_electricity/dorm_electricity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await DormElectricityService.instance.restoreCache(force: true);
  });

  test('restores cached electricity and timestamp from preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 4, 8, 10, 0).millisecondsSinceEpoch;
    await prefs.setDouble('dorm_cached_electricity', 123.45);
    await prefs.setInt('dorm_cached_electricity_updated_at', now);

    await DormElectricityService.instance.restoreCache(force: true);

    expect(DormElectricityService.instance.cachedElectricity, 123.45);
    expect(
      DormElectricityService.instance.lastUpdated,
      DateTime.fromMillisecondsSinceEpoch(now),
    );
  });

  test('uses fresh cache without requesting remote electricity', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setDouble('dorm_cached_electricity', 88.8);
    await prefs.setInt('dorm_cached_electricity_updated_at', now);

    await DormElectricityService.instance.restoreCache(force: true);
    final value = await DormElectricityService.instance.fetchElectricity();

    expect(value, 88.8);
    expect(DormElectricityService.instance.lastError, isNull);
  });
}
