import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/changxing_jiada/changxing_jiada_form_validator.dart';
import 'package:jiaxing_university_portal/features/changxing_jiada/changxing_jiada_model.dart';

ChangxingApplication _application({required int type, required int status}) {
  return ChangxingApplication(
    id: 1,
    type: type,
    status: status,
    userName: '测试用户',
    departmentName: '测试班级',
    userJobNo: '20260001',
    userPhone: '13800000000',
    descr: '测试',
    remark: '',
    trafficTool: '',
    backStatus: 0,
    notBackReason: '',
    emergencyContact: '',
    emergencyPhone: '',
    startTime: DateTime(2026, 4, 8, 8),
    endTime: DateTime(2026, 4, 8, 10),
    upTime: DateTime(2026, 4, 8, 11),
  );
}

void main() {
  group('ChangxingFormValidator', () {
    test('validates mainland phone number', () {
      expect(ChangxingFormValidator.isPhone('13812345678'), isTrue);
      expect(ChangxingFormValidator.isPhone('12812345678'), isFalse);
      expect(ChangxingFormValidator.isPhone('1381234'), isFalse);
    });

    test('validates date order', () {
      final start = DateTime(2026, 4, 8, 10, 0);
      final end = DateTime(2026, 4, 8, 11, 0);

      expect(ChangxingFormValidator.validateDateOrder(start, end), isNull);
      expect(
        ChangxingFormValidator.validateDateOrder(end, start),
        '结束时间需大于开始时间',
      );
    });

    test('validates contact name constraints', () {
      expect(ChangxingFormValidator.validateContactName(''), '紧急联系人为空');
      expect(ChangxingFormValidator.validateContactName('张'), '紧急联系人姓名过短');
      expect(
        ChangxingFormValidator.validateContactName('张三李四王五赵六孙七周八'),
        '紧急联系人姓名过长',
      );
      expect(ChangxingFormValidator.validateContactName('张三'), isNull);
    });

    test('validates reason text constraints', () {
      expect(
        ChangxingFormValidator.validateReason(
          '   ',
          emptyMessage: '理由为空',
          tooLongMessage: '理由过长',
        ),
        '理由为空',
      );

      final tooLong = 'a' * 201;
      expect(
        ChangxingFormValidator.validateReason(
          tooLong,
          emptyMessage: '理由为空',
          tooLongMessage: '理由过长',
        ),
        '理由过长',
      );

      expect(
        ChangxingFormValidator.validateReason(
          '正常理由',
          emptyMessage: '理由为空',
          tooLongMessage: '理由过长',
        ),
        isNull,
      );
    });

    test('validates not-back reason min length', () {
      expect(
        ChangxingFormValidator.validateNotBackReason('太短'),
        '请填写无法报到原因，并不少于10个字',
      );
      expect(
        ChangxingFormValidator.validateNotBackReason('因为在外地隔离无法按时报到'),
        isNull,
      );
    });
  });

  group('ChangxingFormType and canEdit', () {
    test('maps type code to enum route', () {
      expect(ChangxingFormType.fromType(1), ChangxingFormType.leaveRequest);
      expect(ChangxingFormType.fromType(4), ChangxingFormType.overtime);
      expect(ChangxingFormType.fromType(99), isNull);
    });

    test('allows editing only when status is pending', () {
      final pending = _application(type: 2, status: 0);
      final approved = _application(type: 2, status: 1);

      expect(pending.canEdit, isTrue);
      expect(approved.canEdit, isFalse);
    });
  });
}
