import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/core/network/network_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkSettings.instance.debugReset();
  });

  test('loads ignoreSystemProxy from preferences once initialized', () async {
    SharedPreferences.setMockInitialValues({'ignore_system_proxy': false});

    await NetworkSettings.instance.ensureInitialized();

    expect(NetworkSettings.instance.ignoreSystemProxy.value, isFalse);
  });

  test('persists updated ignoreSystemProxy value', () async {
    await NetworkSettings.instance.setIgnoreSystemProxy(false);

    NetworkSettings.instance.debugReset();
    await NetworkSettings.instance.ensureInitialized();

    expect(NetworkSettings.instance.ignoreSystemProxy.value, isFalse);
  });
}
