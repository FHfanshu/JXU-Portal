import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/auth/zhengfang_auth.dart';
import 'package:jiaxing_university_portal/core/network/dio_client.dart';
import 'package:jiaxing_university_portal/features/changxing_jiada/changxing_jiada_service.dart';

import '../../helpers/mock_http_client_adapter.dart';
import '../../helpers/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetTestEnvironment();
    DioClient.instance.debugCookieDirectoryPathProvider = (folderName) async =>
        'test/$folderName';
    await DioClient.instance.ensureInitialized();
  });

  test('changxing requests use unified auth dio', () async {
    await const FlutterSecureStorage().write(
      key: 'zjxu_changxing_token',
      value: 'test-token',
    );

    final requestPath = Uri.parse(
      ZhengfangAuth.instance.buildWebVpnProxyUrl(
        'https://zhx.zjxu.edu.cn/api/msg/getNoReadCount',
      ),
    ).path;

    final unifiedAdapter = MockHttpClientAdapter()
      ..registerJson('GET', requestPath, {
        'data': {'code': '20000', 'count': 3},
      });
    final zhengfangAdapter = MockHttpClientAdapter();

    DioClient.instance.unifiedAuthDio.httpClientAdapter = unifiedAdapter;
    DioClient.instance.dio.httpClientAdapter = zhengfangAdapter;

    final count = await ChangxingJiadaService.instance.fetchUnreadCount();

    expect(count, 3);
    expect(unifiedAdapter.requestLog, ['GET $requestPath']);
    expect(zhengfangAdapter.requestLog, isEmpty);
  });
}
