import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import '../../shared/widgets/unified_auth_protected_webview_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  static const _libraryUrl =
      'https://libapp.zjxu.edu.cn/Info/Thirdparty/ssoFromDingDing';

  String _currentUrl = _libraryUrl;
  String _serviceUrl = _libraryUrl;
  int _webVpnRecoveryAttempts = 0;
  bool _recoveringWebVpn = false;

  Future<void> _handleLoadStop(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    final uri = Uri.tryParse(currentUrl);
    if (uri == null) return;

    final isWebVpnGatewayLogin = isZhengfangGatewayLoginUrl(currentUrl);
    final isWebVpnCasLogin =
        uri.host.toLowerCase() == 'webvpn.zjxu.edu.cn' &&
        uri.path.toLowerCase().contains('/cas/login');
    if (!isWebVpnGatewayLogin && !isWebVpnCasLogin) {
      return;
    }

    if (_recoveringWebVpn || _webVpnRecoveryAttempts > 0) {
      AppLogger.instance.webview(
        LogLevel.warn,
        '图书馆 WebVPN 恢复已尝试，保留当前页面等待用户处理',
      );
      return;
    }

    _recoveringWebVpn = true;
    AppLogger.instance.webview(
      LogLevel.warn,
      '图书馆入口命中 WebVPN 登录链路，切换到 WebVPN 代理页重试',
    );

    try {
      final webVpnReady = await ZhengfangAuth.instance
          .ensureWebVpnGatewaySession();
      if (!mounted || webVpnReady != true) {
        return;
      }

      final proxiedUrl = ZhengfangAuth.instance.buildWebVpnProxyUrl(
        _libraryUrl,
      );
      setState(() {
        _webVpnRecoveryAttempts = 1;
        _currentUrl = proxiedUrl;
        _serviceUrl = ZhengfangAuth.webVpnGatewayServiceUrl;
      });
    } finally {
      _recoveringWebVpn = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnifiedAuthProtectedWebViewPage(
      key: ValueKey('$_currentUrl|$_serviceUrl'),
      title: '图书馆',
      url: _currentUrl,
      serviceUrl: _serviceUrl,
      loginDescription: '统一认证登录后可直接进入图书馆，必要时自动补齐 WebVPN 会话',
      showWebViewBottomBackButton: true,
      onHomePressed: () => context.goNamed('home'),
      onLoadStop: _handleLoadStop,
    );
  }
}
