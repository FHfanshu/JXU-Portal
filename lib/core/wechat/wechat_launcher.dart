import 'package:flutter/services.dart';

import '../logging/app_logger.dart';

class WeChatLauncher {
  WeChatLauncher._();

  static const _channel = MethodChannel(
    'edu.zjxu.jiaxinguniversityportal/wechat',
  );

  static Future<bool> openUrlInWeChat(String url) async {
    try {
      final result = await _channel.invokeMethod<bool>('openUrlInWeChat', {
        'url': url,
      });
      return result ?? false;
    } on PlatformException catch (error) {
      AppLogger.instance.ui(
        LogLevel.error,
        '微信原生拉起失败: ${error.message ?? error.code}',
      );
      return false;
    } catch (error) {
      AppLogger.instance.ui(LogLevel.error, '微信原生拉起异常: $error');
      return false;
    }
  }
}
