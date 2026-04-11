import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import 'auth_required_view.dart';
import 'login_shell.dart';
import 'webview_page.dart';

bool isZhengfangLoginUrl(String currentUrl) {
  return isZhengfangLoginEntryUrl(currentUrl);
}

class ZhengfangProtectedWebViewPage extends StatefulWidget {
  const ZhengfangProtectedWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.loginDescription = '账号为学号',
    this.onLoadStop,
  });

  final String title;
  final String url;
  final String loginDescription;
  final WebViewLoadStopCallback? onLoadStop;

  @override
  State<ZhengfangProtectedWebViewPage> createState() =>
      _ZhengfangProtectedWebViewPageState();
}

class _ZhengfangProtectedWebViewPageState
    extends State<ZhengfangProtectedWebViewPage> {
  late bool _authenticated;
  bool _preparingSession = false;
  bool _recoveryAttempted = false;
  Key _webViewKey = UniqueKey();
  Map<String, String> _initialHeaders = const {};
  bool _loginPromptShown = false;
  bool _loginPromptInFlight = false;

  @override
  void initState() {
    super.initState();
    _authenticated = ZhengfangAuth.instance.isLoggedIn;
    if (_authenticated) {
      _prepareWebViewSession();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showNativeLogin());
      });
    }
  }

  Future<void> _showNativeLogin() async {
    ZhengfangAuth.instance.markLoggedOut();
    if (mounted) {
      setState(() {
        _authenticated = false;
        _preparingSession = false;
        _recoveryAttempted = false;
      });
    }

    if (!mounted || _loginPromptInFlight) return;
    _loginPromptShown = true;
    _loginPromptInFlight = true;
    final loggedIn = await showAcademicSystemLoginModal(context);
    _loginPromptInFlight = false;
    if (!mounted || !loggedIn) return;
    await _prepareWebViewSession(recreateWebView: true);
  }

  Future<void> _handleLoadStop(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    if (isZhengfangLoginUrl(currentUrl)) {
      AppLogger.instance.webview(LogLevel.warn, 'WebView 跳转到教务登录页，尝试恢复会话');

      if (_preparingSession) {
        AppLogger.instance.webview(LogLevel.debug, '教务会话恢复进行中，忽略重复登录页回调');
        return;
      }

      if (_recoveryAttempted || !ZhengfangAuth.instance.isLoggedIn) {
        AppLogger.instance.webview(LogLevel.warn, '教务 WebView 会话恢复失败，切换为应用内登录');
        await _showNativeLogin();
        return;
      }

      _recoveryAttempted = true;
      await _prepareWebViewSession(recreateWebView: true);
      return;
    }

    _recoveryAttempted = false;
    final callback = widget.onLoadStop;
    if (callback != null) {
      await callback(controller, currentUrl);
    }
  }

  Future<void> _prepareWebViewSession({bool recreateWebView = false}) async {
    if (_preparingSession) return;

    if (mounted) {
      setState(() => _preparingSession = true);
    } else {
      _preparingSession = true;
    }

    try {
      final resolvedUrl = ZhengfangAuth.instance.resolvePortalUrl(widget.url);
      await ZhengfangAuth.instance.syncCookiesToWebView();
      final headers = await ZhengfangAuth.instance.buildWebViewHeaders(
        resolvedUrl,
      );
      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _initialHeaders = headers;
        _preparingSession = false;
        if (recreateWebView) {
          _webViewKey = UniqueKey();
        }
      });
    } catch (error) {
      AppLogger.instance.webview(LogLevel.error, '准备教务 WebView 会话失败: $error');
      if (!mounted) return;
      setState(() => _preparingSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticated) {
      if (_preparingSession && _initialHeaders.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return WebViewPage(
        key: _webViewKey,
        title: widget.title,
        url: ZhengfangAuth.instance.resolvePortalUrl(widget.url),
        initialHeaders: _initialHeaders,
        onLoadStop: _handleLoadStop,
      );
    }

    if (!_loginPromptShown && !_loginPromptInFlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_showNativeLogin());
      });
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: AuthRequiredView(
        title: '需要登录后继续',
        message: widget.loginDescription,
        buttonLabel: '登录教务系统',
        onAction: _showNativeLogin,
        icon: Icons.school_outlined,
      ),
    );
  }
}
