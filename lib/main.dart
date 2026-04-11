import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_bootstrap_controller.dart';
import 'core/logging/app_logger.dart';
import 'core/shortcut/app_shortcut_service.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.instance.init();

      FlutterError.onError = (details) {
        AppLogger.instance.ui(
          LogLevel.error,
          'Flutter 框架异常',
          error: details.exception,
          stackTrace: details.stack,
          force: true,
        );
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        AppLogger.instance.log(
          LogLevel.error,
          LogCategory.general,
          'PlatformDispatcher 未捕获异常',
          error: error,
          stackTrace: stackTrace,
          force: true,
        );
        return true;
      };

      await AppBootstrapController.instance.prepareForFirstFrame();
      await AppShortcutService.instance.initialize();
      runApp(const JiaxingUniversityApp());
      AppBootstrapController.instance.scheduleWarmUpAfterFirstFrame();
    },
    (error, stackTrace) {
      AppLogger.instance.log(
        LogLevel.error,
        LogCategory.general,
        'runZonedGuarded 未捕获异常',
        error: error,
        stackTrace: stackTrace,
        force: true,
      );
    },
  );
}
