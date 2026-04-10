import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import 'update_model.dart';
import 'update_service.dart';

enum UpdateCheckStatus { updateAvailable, upToDate, error, checking }

class UpdateCheckResult {
  const UpdateCheckResult(this.status, {this.release});

  final UpdateCheckStatus status;
  final AppRelease? release;
}

class UpdateChecker {
  UpdateChecker._();

  static final UpdateChecker instance = UpdateChecker._();

  final ValueNotifier<AppRelease?> availableRelease =
      ValueNotifier<AppRelease?>(null);
  final ValueNotifier<bool> isChecking = ValueNotifier<bool>(false);

  Future<UpdateCheckResult> check({bool silent = false}) async {
    if (isChecking.value) {
      return const UpdateCheckResult(UpdateCheckStatus.checking);
    }

    isChecking.value = true;
    try {
      final release = await UpdateService.instance.checkForUpdate();
      availableRelease.value = release;
      if (release == null) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }
      return UpdateCheckResult(
        UpdateCheckStatus.updateAvailable,
        release: release,
      );
    } catch (error) {
      AppLogger.instance.debug('更新检查异常: $error');
      return const UpdateCheckResult(UpdateCheckStatus.error);
    } finally {
      isChecking.value = false;
    }
  }

  @visibleForTesting
  void debugReset() {
    availableRelease.value = null;
    isChecking.value = false;
  }
}
