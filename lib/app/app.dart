import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

class JiaxingUniversityApp extends StatefulWidget {
  const JiaxingUniversityApp({super.key});

  @override
  State<JiaxingUniversityApp> createState() => _JiaxingUniversityAppState();
}

class _JiaxingUniversityAppState extends State<JiaxingUniversityApp> {
  final _controller = ThemeModeController.instance;

  @override
  void initState() {
    super.initState();
    _controller.themeMode.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _controller.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '嘉兴大学-校园门户',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _controller.themeMode.value,
      // Disable the built-in AnimatedTheme transition — it forces every
      // Theme.of(context) dependent to rebuild on every animation frame,
      // causing visible jank during light/dark toggle.
      themeAnimationDuration: Duration.zero,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
