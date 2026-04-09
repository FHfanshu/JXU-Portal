import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/auth/unified_auth.dart';
import '../../core/logging/app_logger.dart';
import 'unified_auth_login_widget.dart';
import 'webview_page.dart';

class UnifiedAuthProtectedWebViewPage extends StatefulWidget {
  const UnifiedAuthProtectedWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.serviceUrl = UnifiedAuthService.defaultServiceUrl,
    this.loginDescription = '账号为校园一卡通号',
    this.onLoadStop,
  });

  final String title;
  final String url;
  final String serviceUrl;
  final String loginDescription;
  final WebViewLoadStopCallback? onLoadStop;

  @override
  State<UnifiedAuthProtectedWebViewPage> createState() =>
      _UnifiedAuthProtectedWebViewPageState();
}

class _UnifiedAuthProtectedWebViewPageState
    extends State<UnifiedAuthProtectedWebViewPage> {
  late bool _authenticated;
  late bool _authResolved;
  bool _resyncing = false;

  @override
  void initState() {
    super.initState();
    _authenticated = UnifiedAuthService.instance.isLoggedIn;
    _authResolved = !_authenticated;
    if (!_authResolved) {
      _resolveInitialAuthentication();
    }
  }

  void _onLoginSuccess() {
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _authResolved = true;
    });
  }

  Future<void> _resolveInitialAuthentication() async {
    final validated = await UnifiedAuthService.instance.validateSession(
      serviceUrl: widget.serviceUrl,
    );
    if (!mounted) return;
    setState(() {
      _authenticated = validated ?? UnifiedAuthService.instance.isLoggedIn;
      _authResolved = true;
    });
  }

  Future<void> _handleLoadStop(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    final isUnifiedAuthLogin = isUnifiedAuthLoginEntryUrl(currentUrl);

    if (isUnifiedAuthLogin) {
      AppLogger.instance.debug('WebView 跳转到 CAS 登录页，尝试重新同步 Cookie');

      // 如果已在重试中，或 native 已登出，直接标记登出
      if (_resyncing || !UnifiedAuthService.instance.isLoggedIn) {
        AppLogger.instance.debug('Cookie 重同步失败，标记登出');
        UnifiedAuthService.instance.markLoggedOut();
        if (mounted) setState(() => _authenticated = false);
        return;
      }

      // 第一次：重新同步 cookie 后重新加载
      _resyncing = true;
      await UnifiedAuthService.instance.syncCookiesToWebView();
      AppLogger.instance.debug('Cookie 重同步完成，重新加载 WebView');
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
      return;
    }

    _resyncing = false;
    final callback = widget.onLoadStop;
    if (callback != null) {
      await callback(controller, currentUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authResolved) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_authenticated) {
      return WebViewPage(
        title: widget.title,
        url: widget.url,
        onLoadStop: _handleLoadStop,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: UnifiedAuthLoginWidget(
        serviceUrl: widget.serviceUrl,
        title: '登录统一认证',
        description: widget.loginDescription,
        onLoginSuccess: _onLoginSuccess,
      ),
    );
  }
}
