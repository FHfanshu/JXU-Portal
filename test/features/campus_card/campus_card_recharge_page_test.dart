import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jiaxing_university_portal/core/config/app_config.dart';
import 'package:jiaxing_university_portal/features/campus_card/campus_card_recharge_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wechatChannel = MethodChannel(
    'edu.zjxu.jiaxinguniversityportal/wechat',
  );
  final clipboardCalls = <MethodCall>[];

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wechatChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    clipboardCalls.clear();
  });

  test('exposes stable xiaofubao recharge entry url', () {
    expect(
      CampusCardRechargePage.rechargeHomeUri.toString(),
      AppConfig.xiaofubaoRechargeUri.toString(),
    );
  });

  testWidgets(
    'shows fallback message when wechat launch fails and copies link',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(wechatChannel, (call) async {
            calls.add(call);
            return false;
          });

      await tester.pumpWidget(
        const MaterialApp(home: CampusCardRechargePage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('没有成功拉起微信，请手动复制链接到微信中打开'), findsOneWidget);
      expect(calls.single.method, 'openUrlInWeChat');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            clipboardCalls.add(call);
            return null;
          });

      await tester.tap(find.text('复制充值链接'));
      await tester.pumpAndSettle();

      expect(
        clipboardCalls.any((call) {
          return call.method == 'Clipboard.setData' &&
              (call.arguments as Map)['text'] ==
                  CampusCardRechargePage.rechargeHomeUri.toString();
        }),
        isTrue,
      );
    },
  );
}
