import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../app/app_bootstrap_controller.dart';
import '../../app/routes.dart';
import '../logging/app_logger.dart';

class AppShortcutService {
  AppShortcutService._();

  static final AppShortcutService instance = AppShortcutService._();

  static const campusCardPaymentAction = 'campus-card-payment';

  static const _channel = MethodChannel(
    'edu.zjxu.jiaxinguniversityportal/shortcut',
  );

  bool _initialized = false;
  bool _phaseListenerRegistered = false;
  String? _pendingAction;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler(_handleMethodCall);
    if (!_phaseListenerRegistered) {
      AppBootstrapController.instance.phase.addListener(_flushPendingAction);
      _phaseListenerRegistered = true;
    }

    try {
      final initialAction = await _channel.invokeMethod<String>(
        'consumeInitialShortcutAction',
      );
      _queueAction(initialAction);
    } on MissingPluginException {
      // Non-Android platforms and tests do not register the native channel.
    } on PlatformException catch (error) {
      AppLogger.instance.error('读取快捷方式启动动作失败: ${error.message ?? error.code}');
    } catch (error) {
      AppLogger.instance.error('读取快捷方式启动动作异常: $error');
    }
  }

  Future<bool> requestCampusCardPaymentShortcut() async {
    await initialize();

    try {
      final result = await _channel.invokeMethod<bool>(
        'requestCampusCardPaymentShortcut',
      );
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (error) {
      AppLogger.instance.error('添加付款码快捷方式失败: ${error.message ?? error.code}');
      return false;
    } catch (error) {
      AppLogger.instance.error('添加付款码快捷方式异常: $error');
      return false;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onShortcutAction') return;
    _queueAction(call.arguments as String?);
  }

  void _queueAction(String? action) {
    final normalized = action?.trim() ?? '';
    if (normalized.isEmpty) return;

    _pendingAction = normalized;
    _flushPendingAction();
  }

  void _flushPendingAction() {
    final action = _pendingAction;
    if (action == null || !_isNavigationReady) return;

    _pendingAction = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (action) {
        case campusCardPaymentAction:
          unawaited(appRouter.pushNamed('campus-card-payment'));
          break;
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  bool get _isNavigationReady {
    final phase = AppBootstrapController.instance.phase.value;
    return phase == AppBootstrapPhase.localStateReady ||
        phase == AppBootstrapPhase.completed;
  }
}
