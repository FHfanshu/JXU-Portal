import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/core/logging/app_logger.dart';
import 'package:jiaxing_university_portal/core/wechat/wechat_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wechatChannel = MethodChannel(
    'edu.zjxu.jiaxinguniversityportal/wechat',
  );

  setUp(() {
    AppLogger.instance.debugReset();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wechatChannel, null);
  });

  test('returns platform result when opening url in wechat', () async {
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wechatChannel, (call) async {
          receivedCall = call;
          return true;
        });

    final launched = await WeChatLauncher.openUrlInWeChat(
      'https://example.com',
    );

    expect(launched, isTrue);
    expect(receivedCall?.method, 'openUrlInWeChat');
    expect((receivedCall?.arguments as Map)['url'], 'https://example.com');
  });

  test('returns false and logs when platform throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(wechatChannel, (_) async {
          throw PlatformException(code: 'fail', message: 'boom');
        });

    final launched = await WeChatLauncher.openUrlInWeChat(
      'https://example.com',
    );

    expect(launched, isFalse);
    expect(AppLogger.instance.entries.last.message, contains('微信原生拉起失败'));
  });
}
