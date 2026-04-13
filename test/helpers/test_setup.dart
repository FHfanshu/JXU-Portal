import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/app/text_scale_controller.dart';
import 'package:jiaxing_university_portal/core/auth/unified_auth.dart';
import 'package:jiaxing_university_portal/core/auth/zhengfang_auth.dart';
import 'package:jiaxing_university_portal/core/network/dio_client.dart';
import 'package:jiaxing_university_portal/core/logging/app_logger.dart';
import 'package:jiaxing_university_portal/core/network/network_settings.dart';
import 'package:jiaxing_university_portal/core/update/update_checker.dart';
import 'package:jiaxing_university_portal/core/update/update_service.dart';
import 'package:jiaxing_university_portal/features/campus_card/campus_card_service.dart';
import 'package:jiaxing_university_portal/features/dorm_electricity/dorm_electricity_service.dart';
import 'package:jiaxing_university_portal/features/schedule/schedule_service.dart';

Future<void> resetTestEnvironment() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  PackageInfo.setMockInitialValues(
    appName: '嘉兴大学-校园门户',
    packageName: 'test.package',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: 'test',
  );

  TextScaleController.instance.debugReset();
  UnifiedAuthService.instance.debugReset();
  ZhengfangAuth.instance.debugReset();
  NetworkSettings.instance.debugReset();
  DioClient.instance.debugReset();
  AppLogger.instance.debugReset();
  UpdateService.instance.debugReset();
  UpdateChecker.instance.debugReset();
  CampusCardService.instance.debugSetCachedBalance(null);
  DormElectricityService.instance.debugReset();
  await ScheduleService.instance.debugClearCache();
}
