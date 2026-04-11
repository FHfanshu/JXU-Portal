import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/logging/app_logger.dart';
import 'package:jiaxing_university_portal/features/notice/notice_service.dart';

import '../../helpers/mock_http_client_adapter.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUp(() async {
    await resetTestEnvironment();
    NoticeService.instance.debugReset();
  });

  tearDown(() {
    NoticeService.instance.debugReset();
  });

  test('logs error when notice list load fails without cache', () async {
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes))
      ..httpClientAdapter = MockHttpClientAdapter();
    NoticeService.instance.debugSetDio(dio);

    await expectLater(NoticeService.instance.fetchNotices(), throwsA(anything));

    final messages = AppLogger.instance.entries.map((entry) => entry.message);
    expect(messages, contains('开始加载通知公告列表'));
    expect(messages, contains('通知公告加载失败'));
    expect(
      AppLogger.instance.entries.any((entry) => entry.level == LogLevel.error),
      isTrue,
    );
  });
}
