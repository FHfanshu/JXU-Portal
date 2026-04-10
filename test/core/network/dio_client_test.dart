import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jiaxing_university_portal/core/network/dio_client.dart';
import 'package:jiaxing_university_portal/core/network/network_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkSettings.instance.debugReset();
    DioClient.instance.debugReset();
    DioClient.instance.debugCookieDirectoryPathProvider = (folderName) async {
      final dir = await Directory.systemTemp.createTemp('dio_client_test_');
      return '${dir.path}/$folderName/';
    };
  });

  tearDown(() {
    DioClient.instance.debugReset();
    NetworkSettings.instance.debugReset();
  });

  test('ensureInitialized is idempotent', () async {
    await DioClient.instance.ensureInitialized();
    final dio = DioClient.instance.dio;
    final unifiedAuthDio = DioClient.instance.unifiedAuthDio;
    final cookieJar = DioClient.instance.cookieJar;
    final unifiedAuthCookieJar = DioClient.instance.unifiedAuthCookieJar;

    await DioClient.instance.ensureInitialized();

    expect(identical(dio, DioClient.instance.dio), isTrue);
    expect(
      identical(unifiedAuthDio, DioClient.instance.unifiedAuthDio),
      isTrue,
    );
    expect(identical(cookieJar, DioClient.instance.cookieJar), isTrue);
    expect(
      identical(unifiedAuthCookieJar, DioClient.instance.unifiedAuthCookieJar),
      isTrue,
    );
    expect(identical(dio, unifiedAuthDio), isFalse);
    expect(identical(cookieJar, unifiedAuthCookieJar), isFalse);
  });
}
