import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/campus_card/campus_card_recharge_page.dart';

void main() {
  test('exposes stable xiaofubao recharge entry url', () {
    expect(
      CampusCardRechargePage.rechargeHomeUri.toString(),
      'https://webapp.xiaofubao.com/card/card_home.shtml?platform=WECHAT_H5&schoolCode=10354&thirdAppid=wx8fddf03d92fd6fa9',
    );
  });
}
