import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeController {
  ThemeModeController._();

  static final ThemeModeController instance = ThemeModeController._();

  static const _prefKey = 'theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// Load persisted theme mode. Call once at app startup before runApp().
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_prefKey);
    if (stored != null && stored >= 0 && stored < ThemeMode.values.length) {
      themeMode.value = ThemeMode.values[stored];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) return;
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, mode.index);
  }

  @visibleForTesting
  void debugReset({ThemeMode mode = ThemeMode.system}) {
    themeMode.value = mode;
  }
}
