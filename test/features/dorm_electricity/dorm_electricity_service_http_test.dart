import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/dorm_electricity/dorm_electricity_service.dart';

import '../../helpers/mock_http_client_adapter.dart';
import '../../helpers/test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetTestEnvironment();
  });

  test('fetchElectricity parses html response through mocked dio', () async {
    const config = DormRoomConfig(
      communityId: '1',
      buildingId: '2',
      floorId: '3',
      roomId: '4',
    );
    await DormElectricityService.instance.saveRoomConfig(config);

    final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
    final adapter = MockHttpClientAdapter()
      ..register(
        'GET',
        '/DormCharge/BaseElect/queryResult/ele_id/1/community_id/1/building_id/2/floor_id/3/room_id/4',
        (_) async => ResponseBody.fromBytes(
          utf8.encode('<html><body>实际剩余电量（度）：42.50</body></html>'),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['text/html; charset=utf-8'],
          },
        ),
      );
    dio.httpClientAdapter = adapter;
    DormElectricityService.instance.debugSetDio(dio);

    final value = await DormElectricityService.instance.fetchElectricity(
      forceRefresh: true,
    );

    expect(value, 42.5);
    expect(DormElectricityService.instance.lastError, isNull);
  });

  test('fetchBuildings flattens nested response payload', () async {
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
    final adapter = MockHttpClientAdapter()
      ..register(
        'POST',
        '/dormcharge/base_elect/getParkBuild/ele_id/1',
        (_) async => ResponseBody.fromBytes(
          utf8.encode(
            jsonEncode({
              'data': [
                {
                  'id': 1,
                  'value': '梁林',
                  'childs': [
                    {'id': 11, 'value': '1号楼'},
                  ],
                },
              ],
            }),
          ),
          200,
        ),
      );
    dio.httpClientAdapter = adapter;
    DormElectricityService.instance.debugSetDio(dio);

    final buildings = await DormElectricityService.instance.fetchBuildings();

    expect(buildings, hasLength(1));
    expect(buildings.single.communityName, '梁林');
    expect(buildings.single.buildingName, '1号楼');
  });
}
