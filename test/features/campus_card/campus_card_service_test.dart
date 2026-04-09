import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/campus_card/campus_card_service.dart';

void main() {
  final service = CampusCardService.instance;

  group('CampusCardService.parseBalanceFromPageText', () {
    test('parses amount from same line with currency sign', () {
      final balance = service.parseBalanceFromPageText('卡内余额：￥23.50 元');

      expect(balance, 23.5);
    });

    test('parses amount near balance label on adjacent line', () {
      final balance = service.parseBalanceFromPageText('''
校园卡信息
18.25 元
卡内余额
''');

      expect(balance, 18.25);
    });

    test('returns null when no balance text exists', () {
      final balance = service.parseBalanceFromPageText('当前页面没有余额字段');

      expect(balance, isNull);
    });
  });
}
