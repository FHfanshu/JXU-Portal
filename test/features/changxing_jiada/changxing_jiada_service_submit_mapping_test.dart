import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/changxing_jiada/changxing_jiada_service.dart';

void main() {
  group('ChangxingJiadaService submit mapping', () {
    final start = DateTime(2026, 4, 8, 8, 0);
    final end = DateTime(2026, 4, 8, 18, 0);

    test('buildLeaveRequestSubmitRequest maps add endpoint and payload', () {
      final request = ChangxingJiadaService.buildLeaveRequestSubmitRequest(
        startTime: start,
        endTime: end,
        descr: '请假事由',
        toAreaCode: 330402,
        toAddr: '南湖区测试路 1 号',
        emergencyContact: '张三',
        emergencyPhone: '13800000001',
        userPhone: '13800000002',
        trafficTools: const <String>['高铁', '自驾'],
        img: 'img-md5',
        annex: 'annex-md5',
      );

      expect(request.path, '/approvalForm/qingjia/add');
      expect(request.payload['id'], isNull);
      expect(request.payload['type'], 1);
      expect(request.payload['trafficTool'], '高铁,自驾');
      expect(request.payload['img'], 'img-md5');
      expect(request.payload['annex'], 'annex-md5');
    });

    test(
      'buildLeaveRequestSubmitRequest maps edit endpoint and includes id',
      () {
        final request = ChangxingJiadaService.buildLeaveRequestSubmitRequest(
          id: 1001,
          startTime: start,
          endTime: end,
          descr: '请假事由',
          toAreaCode: 330402,
          toAddr: '南湖区测试路 1 号',
          emergencyContact: '张三',
          emergencyPhone: '13800000001',
          userPhone: '13800000002',
          trafficTools: const <String>['高铁'],
        );

        expect(request.path, '/approvalForm/edit');
        expect(request.payload['id'], 1001);
        expect(request.payload['type'], 1);
      },
    );

    test('buildLeaveSchoolSubmitRequest maps add and edit endpoints', () {
      final addRequest = ChangxingJiadaService.buildLeaveSchoolSubmitRequest(
        startTime: start,
        endTime: end,
        descr: '离校事由',
        toAreaCode: 330402,
        toAddr: '南湖区测试路 2 号',
        emergencyContact: '李四',
        emergencyPhone: '13800000003',
        userPhone: '13800000004',
        trafficTools: const <String>['客车'],
      );
      final editRequest = ChangxingJiadaService.buildLeaveSchoolSubmitRequest(
        id: 2002,
        startTime: start,
        endTime: end,
        descr: '离校事由',
        toAreaCode: 330402,
        toAddr: '南湖区测试路 2 号',
        emergencyContact: '李四',
        emergencyPhone: '13800000003',
        userPhone: '13800000004',
        trafficTools: const <String>['客车'],
      );

      expect(addRequest.path, '/approvalForm/lixiao/add');
      expect(addRequest.payload['type'], 2);
      expect(addRequest.payload['id'], isNull);

      expect(editRequest.path, '/approvalForm/edit');
      expect(editRequest.payload['type'], 2);
      expect(editRequest.payload['id'], 2002);
    });

    test('buildBackSchoolSubmitRequest maps add and edit endpoints', () {
      final addRequest = ChangxingJiadaService.buildBackSchoolSubmitRequest(
        userPhone: '13800000005',
        startTime: start,
        trafficTool: '高铁',
        trafficDetail: 'G1234 嘉兴南站',
        nativePlace: '浙江嘉兴',
        fromAreaCode: 330402,
        emergencyContact: '王五',
        emergencyPhone: '13800000006',
        backStatus: 0,
        notBackReason: '',
        img: 'img',
        annex: 'annex',
      );
      final editRequest = ChangxingJiadaService.buildBackSchoolSubmitRequest(
        id: 3003,
        userPhone: '13800000005',
        startTime: start,
        trafficTool: '高铁',
        trafficDetail: 'G1234 嘉兴南站',
        nativePlace: '浙江嘉兴',
        fromAreaCode: 330402,
        emergencyContact: '王五',
        emergencyPhone: '13800000006',
        backStatus: 2,
        notBackReason: '暂缓返校原因',
      );

      expect(addRequest.path, '/approvalForm/fanxiao/add');
      expect(addRequest.payload['type'], 3);
      expect(addRequest.payload['id'], isNull);
      expect(addRequest.payload['trafficTool'], '高铁');

      expect(editRequest.path, '/approvalForm/edit');
      expect(editRequest.payload['type'], 3);
      expect(editRequest.payload['id'], 3003);
    });

    test('buildOvertimeSubmitRequest keeps same endpoint for add and edit', () {
      final addRequest = ChangxingJiadaService.buildOvertimeSubmitRequest(
        descr: '超时理由',
      );
      final editRequest = ChangxingJiadaService.buildOvertimeSubmitRequest(
        id: 4004,
        descr: '超时理由',
      );

      expect(addRequest.path, '/approvalForm/overtime/add');
      expect(addRequest.payload['type'], 4);
      expect(addRequest.payload['id'], isNull);

      expect(editRequest.path, '/approvalForm/overtime/add');
      expect(editRequest.payload['type'], 4);
      expect(editRequest.payload['id'], 4004);
    });
  });
}
