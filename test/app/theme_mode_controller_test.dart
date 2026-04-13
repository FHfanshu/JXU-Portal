import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/app/theme_mode_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeModeController.instance.debugReset();
  });

  test('loads stored theme mode during init', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.index,
    });

    await ThemeModeController.instance.init();

    expect(ThemeModeController.instance.themeMode.value, ThemeMode.dark);
  });

  test('ignores invalid stored theme mode', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 999});

    await ThemeModeController.instance.init();

    expect(ThemeModeController.instance.themeMode.value, ThemeMode.system);
  });

  test('persists selected theme mode', () async {
    await ThemeModeController.instance.setThemeMode(ThemeMode.light);

    ThemeModeController.instance.debugReset();
    await ThemeModeController.instance.init();

    expect(ThemeModeController.instance.themeMode.value, ThemeMode.light);
  });
}
