import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/features/campus_card/campus_card_recharge_page.dart';

void main() {
  test('exposes stable xiaofubao recharge entry url', () {
    expect(
      CampusCardRechargePage.rechargeHomeUri.toString(),
      'https://webapp.xiaofubao.com/card/card_home.shtml?platform=WECHAT_H5&schoolCode=10354&thirdAppid=wx8fddf03d92fd6fa9',
    );
  });

  group('CampusCardRechargePage.buildWeChatBusinessWebViewUri', () {
    test('wraps h5 url into wechat business webview scheme', () {
      final uri = CampusCardRechargePage.buildWeChatBusinessWebViewUri(
        CampusCardRechargePage.rechargeHomeUri.toString(),
        appId: CampusCardRechargePage.weChatOAuthAppId,
      );

      expect(uri.scheme, 'weixin');
      expect(uri.host, 'dl');
      expect(uri.path, '/businessWebview/link/');
      expect(uri.queryParameters['appid'], 'wx73282a5b4a6708c1');
      expect(
        uri.queryParameters['url'],
        'https://webapp.xiaofubao.com/card/card_home.shtml?platform=WECHAT_H5&schoolCode=10354&thirdAppid=wx8fddf03d92fd6fa9',
      );
    });
  });
}
