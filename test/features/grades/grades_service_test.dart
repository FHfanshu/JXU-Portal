import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/network/dio_client.dart';
import 'package:jiaxing_university_portal/features/grades/grades_service.dart';

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

  test('fetchGrades posts expected payload and maps items', () async {
    final adapter = MockHttpClientAdapter();
    adapter.register('POST', '/jwglxt/cjcx/cjcx_cxDgXscj.html', (
      options,
    ) async {
      expect(options.queryParameters['doType'], 'query');
      expect(options.queryParameters['gnmkdm'], 'N305005');
      expect(options.queryParameters['su'], '20250001');
      expect(options.data, contains('queryModel.showCount=100'));
      expect(options.data, contains('queryModel.currentPage=1'));
      return ResponseBody.fromString(
        jsonEncode({
          'items': [
            {
              'kcmc': '大学英语',
              'cj': '良好',
              'bfzcj': '86',
              'jd': '3.8',
              'xf': '2.0',
            },
          ],
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    });
    DioClient.instance.dio.httpClientAdapter = adapter;

    final result = await GradesService.instance.fetchGrades('20250001');

    expect(adapter.requestLog, ['POST /jwglxt/cjcx/cjcx_cxDgXscj.html']);
    expect(result, hasLength(1));
    expect(result.single.courseName, '大学英语');
    expect(result.single.gpaPoints, 3.8);
  });

  test('fetchGrades returns empty list when items absent', () async {
    final adapter = MockHttpClientAdapter()
      ..registerJson('POST', '/jwglxt/cjcx/cjcx_cxDgXscj.html', {'rows': []});
    DioClient.instance.dio.httpClientAdapter = adapter;

    final result = await GradesService.instance.fetchGrades('20250001');

    expect(result, isEmpty);
  });
}
