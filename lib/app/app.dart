import 'package:flutter/material.dart';

import 'routes.dart';
import 'text_scale_controller.dart';
import 'theme.dart';
import 'theme_mode_controller.dart';

class JiaxingUniversityApp extends StatefulWidget {
  const JiaxingUniversityApp({super.key});

  @override
  State<JiaxingUniversityApp> createState() => _JiaxingUniversityAppState();
}

class _JiaxingUniversityAppState extends State<JiaxingUniversityApp> {
  final _themeModeController = ThemeModeController.instance;
  final _textScaleController = TextScaleController.instance;

  @override
  void initState() {
    super.initState();
    _themeModeController.themeMode.addListener(_onAppAppearanceChanged);
    _textScaleController.textScaleFactor.addListener(_onAppAppearanceChanged);
  }

  @override
  void dispose() {
    _themeModeController.themeMode.removeListener(_onAppAppearanceChanged);
    _textScaleController.textScaleFactor.removeListener(
      _onAppAppearanceChanged,
    );
    super.dispose();
  }

  void _onAppAppearanceChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '嘉兴大学-校园门户',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeModeController.themeMode.value,
      // Disable the built-in AnimatedTheme transition — it forces every
      // Theme.of(context) dependent to rebuild on every animation frame,
      // causing visible jank during light/dark toggle.
      themeAnimationDuration: Duration.zero,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return AppTextScaleScope(
          scaleFactor: _textScaleController.textScaleFactor.value,
          child: child,
        );
      },
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
