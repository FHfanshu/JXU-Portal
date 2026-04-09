import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/core/config/app_config.dart';
import 'package:jiaxing_university_portal/features/campus_card/campus_card_recharge_page.dart';

void main() {
  test('exposes stable xiaofubao recharge entry url', () {
    expect(
      CampusCardRechargePage.rechargeHomeUri.toString(),
      AppConfig.xiaofubaoRechargeUri.toString(),
    );
  });
}
