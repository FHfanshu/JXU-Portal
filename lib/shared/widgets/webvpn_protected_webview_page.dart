import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/auth/unified_auth.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import 'auth_required_view.dart';
import 'login_shell.dart';
import 'webview_page.dart';

class WebVpnProtectedWebViewPage extends StatefulWidget {
  const WebVpnProtectedWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.showWebViewBottomBackButton = false,
    this.onHomePressed,
    this.appBarActions = const [],
  });

  final String title;
  final String url;
  final bool showWebViewBottomBackButton;
  final VoidCallback? onHomePressed;
  final List<Widget> appBarActions;

  @override
  State<WebVpnProtectedWebViewPage> createState() =>
      _WebVpnProtectedWebViewPageState();
}

class _WebVpnProtectedWebViewPageState
    extends State<WebVpnProtectedWebViewPage> {
  bool _preparingSession = true;
  bool _requiresLogin = false;
  bool _loginPromptShown = false;
  bool _loginPromptInFlight = false;
  Key _webViewKey = UniqueKey();
  DateTime? _casLoginPageSeenAt;

  @override
  void initState() {
    super.initState();
    _resolveInitialSession();
  }

  Future<void> _resolveInitialSession() async {
    final valid = await ZhengfangAuth.instance.validateWebVpnTargetSession(
      widget.url,
    );
    if (!mounted) return;

    if (valid == false) {
      setState(() {
        _preparingSession = false;
        _requiresLogin = true;
      });
      return;
    }

    await _prepareWebViewSession();
  }

  Future<void> _prepareWebViewSession({bool recreateWebView = false}) async {
    try {
      ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);
      await ZhengfangAuth.instance.syncWebVpnCookiesToWebView();
    } catch (error) {
      AppLogger.instance.webview(
        LogLevel.error,
        '准备 WebVPN WebView 会话失败: $error',
      );
    }

    if (!mounted) return;
    setState(() {
      _preparingSession = false;
      _requiresLogin = false;
      if (recreateWebView) {
        _webViewKey = UniqueKey();
      }
    });
  }

  Future<void> _presentLoginPrompt({bool force = false}) async {
    if (!mounted || _loginPromptInFlight) return;
    if (!force && _loginPromptShown) return;

    _loginPromptShown = true;
    _loginPromptInFlight = true;
    final loggedIn = await showWebVpnUnifiedAuthModal(
      context,
      title: '登录一卡通',
      description: '${widget.title} 通过 WebVPN 提供，需先完成一卡通认证',
    );
    _loginPromptInFlight = false;
    if (!mounted || !loggedIn) return;
    await _prepareWebViewSession(recreateWebView: true);
  }

  void _scheduleLoginPrompt({bool force = false}) {
    if (!force && (_loginPromptShown || _loginPromptInFlight)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_presentLoginPrompt(force: force));
    });
  }

  Future<void> _handleLoadStop(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    if (isZhengfangGatewayLoginUrl(currentUrl)) {
      AppLogger.instance.webview(
        LogLevel.warn,
        'WebVPN WebView 命中网关登录页，切换为应用内登录',
      );
      if (mounted) {
        setState(() => _requiresLogin = true);
      }
      await _presentLoginPrompt(force: true);
      return;
    }

    if (isZhengfangLoginEntryUrl(currentUrl)) {
      // CAS 登录页带 service 参数：如果 WebVPN 已认证，CAS SSO 会自动完成
      // 重定向回目标页面，不需要手动登录
      final uri = Uri.tryParse(currentUrl);
      final hasServiceParam =
          uri?.queryParameters.containsKey('service') ?? false;
      final canReuseSession =
          UnifiedAuthService.instance.isLoggedIn ||
          ZhengfangAuth.instance.isWebVpnLoggedIn;
      if (hasServiceParam && canReuseSession) {
        AppLogger.instance.webview(
          LogLevel.debug,
          'WebVPN WebView 命中 CAS 登录页且可复用认证，等待 SSO 自动重定向',
        );
        // 记录首次看到 CAS 登录页的时间，如果 5 秒后仍在登录页则回退到手动登录
        if (_casLoginPageSeenAt == null) {
          _casLoginPageSeenAt = DateTime.now();
          Future.delayed(const Duration(seconds: 5), () {
            if (!mounted) return;
            if (_casLoginPageSeenAt == null) return;
            _casLoginPageSeenAt = null;
            // 仍在 CAS 登录页：SSO 未自动完成，回退到手动登录
            if (_requiresLogin) return;
            AppLogger.instance.webview(
              LogLevel.warn,
              'CAS SSO 自动重定向超时，回退到手动登录',
            );
            _presentLoginPrompt(force: true);
          });
        }
        return;
      }

      _casLoginPageSeenAt = null;
      AppLogger.instance.webview(
        LogLevel.warn,
        'WebVPN WebView 命中登录页，切换为应用内登录',
      );
      if (mounted) {
        setState(() => _requiresLogin = true);
      }
      await _presentLoginPrompt(force: true);
      return;
    }

    _casLoginPageSeenAt = null;

    if (mounted && _requiresLogin) {
      setState(() => _requiresLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_preparingSession) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: widget.appBarActions,
        ),
        body: _buildCheckingBody(context),
      );
    }

    if (_requiresLogin) {
      _scheduleLoginPrompt();

      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: widget.appBarActions,
        ),
        body: AuthRequiredView(
          title: '需要 WebVPN 认证后继续',
          message: '${widget.title} 通过 WebVPN 提供，需先完成一卡通认证',
          buttonLabel: '登录一卡通',
          onAction: () => _presentLoginPrompt(force: true),
          icon: Icons.vpn_lock_outlined,
        ),
      );
    }

    return WebViewPage(
      key: _webViewKey,
      title: widget.title,
      url: ZhengfangAuth.instance.buildWebVpnProxyUrl(widget.url),
      enableLoginQuickFill: true,
      onLoadStop: _handleLoadStop,
      showWebViewBottomBackButton: widget.showWebViewBottomBackButton,
      onHomePressed: widget.onHomePressed,
      appBarActions: widget.appBarActions,
    );
  }

  Widget _buildCheckingBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              '正在校验 WebVPN 登录态',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '若登录已失效，将自动拉起一卡通认证',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
