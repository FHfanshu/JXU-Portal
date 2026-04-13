import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/auth/unified_auth.dart';
import '../core/auth/zhengfang_auth.dart';
import '../core/logging/app_logger.dart';
import '../core/network/dio_client.dart';
import '../core/network/network_settings.dart';
import '../core/semester/semester_calendar.dart';
import '../core/update/update_checker.dart';
import '../features/campus_card/campus_card_service.dart';
import '../features/changxing_jiada/changxing_jiada_service.dart';
import '../features/dorm_electricity/dorm_electricity_service.dart';
import '../features/schedule/schedule_service.dart';
import 'text_scale_controller.dart';
import 'theme_mode_controller.dart';

enum AppBootstrapPhase { idle, warming, localStateReady, completed }

class AppBootstrapController {
  AppBootstrapController._();

  static final AppBootstrapController instance = AppBootstrapController._();

  final ValueNotifier<AppBootstrapPhase> phase = ValueNotifier(
    AppBootstrapPhase.idle,
  );

  Future<void>? _prepareFuture;
  Future<void>? _warmUpFuture;
  bool _warmUpScheduled = false;

  Future<void> prepareForFirstFrame() async {
    final existing = _prepareFuture;
    if (existing != null) return existing;

    final future = Future.wait<void>([
      TextScaleController.instance.init(),
      ThemeModeController.instance.init(),
      SemesterCalendar.instance.init(),
    ]);
    _prepareFuture = future;
    await future;
  }

  void scheduleWarmUpAfterFirstFrame() {
    if (_warmUpScheduled) return;
    _warmUpScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(warmUpAfterFirstFrame());
    });
  }

  Future<void> warmUpAfterFirstFrame() async {
    final existing = _warmUpFuture;
    if (existing != null) return existing;

    final future = _runWarmUp();
    _warmUpFuture = future;
    try {
      await future;
    } catch (_) {
      if (identical(_warmUpFuture, future)) {
        _warmUpFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _runWarmUp() async {
    phase.value = AppBootstrapPhase.warming;

    await AppLogger.instance.init();
    await NetworkSettings.instance.ensureInitialized();
    await DioClient.instance.ensureInitialized();

    await Future.wait<void>([
      ZhengfangAuth.instance.restoreSession(),
      UnifiedAuthService.instance.restoreSession(syncWebViewCookies: false),
      CampusCardService.instance.restoreBalance(),
      ChangxingJiadaService.instance.restoreSession(),
      DormElectricityService.instance.restoreCache(),
      ScheduleService.instance.restoreCache(),
    ]);

    phase.value = AppBootstrapPhase.localStateReady;
    await Future<void>.delayed(Duration.zero);
    phase.value = AppBootstrapPhase.completed;
    unawaited(UpdateChecker.instance.check(silent: true));
  }

  @visibleForTesting
  void debugReset({AppBootstrapPhase phaseValue = AppBootstrapPhase.idle}) {
    _prepareFuture = null;
    _warmUpFuture = null;
    _warmUpScheduled = false;
    phase.value = phaseValue;
  }

  @visibleForTesting
  void debugSetPhase(AppBootstrapPhase phaseValue) {
    phase.value = phaseValue;
  }
}
