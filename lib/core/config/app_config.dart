abstract final class AppConfig {
  static const xiaofubaoThirdAppId = 'wx8fddf03d92fd6fa9';
  static const xiaofubaoSchoolCode = '10354';
  static const xiaofubaoRechargeBaseUrl =
      'https://webapp.xiaofubao.com/card/card_home.shtml';

  static Uri get xiaofubaoRechargeUri => Uri.parse(
    '$xiaofubaoRechargeBaseUrl?platform=WECHAT_H5&schoolCode=$xiaofubaoSchoolCode&thirdAppid=$xiaofubaoThirdAppId',
  );
}
