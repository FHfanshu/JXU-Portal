import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/auth/unified_auth.dart';
import '../../core/logging/app_logger.dart';
import 'auth_required_view.dart';
import 'login_shell.dart';
import 'webview_page.dart';

class UnifiedAuthProtectedWebViewPage extends StatefulWidget {
  const UnifiedAuthProtectedWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.serviceUrl = UnifiedAuthService.defaultServiceUrl,
    this.loginDescription = '账号为校园一卡通号',
    this.onLoadStop,
    this.onNavigationRequest,
    this.emulateDingTalkEnvironment = true,
    this.preferWebViewBackNavigation = false,
    this.onHomePressed,
    this.appBarActions = const [],
  });

  final String title;
  final String url;
  final String serviceUrl;
  final String loginDescription;
  final WebViewLoadStopCallback? onLoadStop;
  final WebViewNavigationRequestCallback? onNavigationRequest;
  final bool emulateDingTalkEnvironment;
  final bool preferWebViewBackNavigation;
  final VoidCallback? onHomePressed;
  final List<Widget> appBarActions;

  @override
  State<UnifiedAuthProtectedWebViewPage> createState() =>
      _UnifiedAuthProtectedWebViewPageState();
}

class _UnifiedAuthProtectedWebViewPageState
    extends State<UnifiedAuthProtectedWebViewPage> {
  late bool _authenticated;
  late bool _authResolved;
  late String _webViewUrl;
  bool _resyncing = false;
  bool _loginPromptShown = false;
  bool _loginPromptInFlight = false;
  Key _webViewKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _webViewUrl = widget.url;
    _authenticated = UnifiedAuthService.instance.isLoggedIn;
    _authResolved = !_authenticated;
    if (!_authResolved) {
      _resolveInitialAuthentication();
    }
  }

  @override
  void didUpdateWidget(covariant UnifiedAuthProtectedWebViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;

    _webViewUrl = widget.url;
    _webViewKey = UniqueKey();
  }

  void _onLoginSuccess() {
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _authResolved = true;
    });
  }

  Future<void> _presentLoginPrompt({bool force = false}) async {
    if (!mounted || _loginPromptInFlight || _authenticated) return;
    if (!force && _loginPromptShown) return;

    _loginPromptShown = true;
    _loginPromptInFlight = true;
    final loggedIn = await showUnifiedAuthLoginModal(
      context,
      title: '登录统一认证',
      description: widget.loginDescription,
      serviceUrl: widget.serviceUrl,
    );
    _loginPromptInFlight = false;
    if (!mounted || !loggedIn) return;
    _onLoginSuccess();
  }

  void _scheduleLoginPrompt({bool force = false}) {
    if (!force &&
        (_loginPromptShown || _loginPromptInFlight || _authenticated)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_presentLoginPrompt(force: force));
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
        if (mounted) {
          setState(() {
            _authenticated = false;
            _authResolved = true;
          });
        }
        await _presentLoginPrompt(force: true);
        return;
      }

      // 第一次：重新同步 cookie 后重新加载
      _resyncing = true;
      await UnifiedAuthService.instance.syncCookiesToWebView();
      if (!mounted) return;

      final retryUrl =
          extractUnifiedAuthServiceUrl(currentUrl) ??
          (currentUrl.trim().isNotEmpty ? currentUrl : widget.url);
      AppLogger.instance.debug('Cookie 重同步完成，重新加载 WebView: $retryUrl');
      // 通过快捷方式快速进入时，这里的旧 controller 偶发会失效。
      // 直接重建 WebView 比继续调用旧实例更稳定。
      setState(() {
        _webViewUrl = retryUrl;
        _webViewKey = UniqueKey();
      });
      return;
    }

    _resyncing = false;
    final callback = widget.onLoadStop;
    if (callback != null) {
      await callback(controller, currentUrl);
    }
  }

  Widget? _buildAppBarLeading(BuildContext context) {
    if (widget.onHomePressed == null) return null;

    final canPop = Navigator.of(context).canPop();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPop)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: '返回主页',
          onPressed: widget.onHomePressed,
        ),
      ],
    );
  }

  double? _appBarLeadingWidth(BuildContext context) {
    if (widget.onHomePressed == null) return null;
    return Navigator.of(context).canPop() ? 96 : 48;
  }

  @override
  Widget build(BuildContext context) {
    if (!_authResolved) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.onHomePressed == null,
          leadingWidth: _appBarLeadingWidth(context),
          leading: _buildAppBarLeading(context),
          title: Text(widget.title),
          actions: widget.appBarActions,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_authenticated) {
      return WebViewPage(
        key: _webViewKey,
        title: widget.title,
        url: _webViewUrl,
        onLoadStop: _handleLoadStop,
        onNavigationRequest: widget.onNavigationRequest,
        emulateDingTalkEnvironment: widget.emulateDingTalkEnvironment,
        preferWebViewBackNavigation: widget.preferWebViewBackNavigation,
        onHomePressed: widget.onHomePressed,
        appBarActions: widget.appBarActions,
      );
    }

    _scheduleLoginPrompt();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onHomePressed == null,
        leadingWidth: _appBarLeadingWidth(context),
        leading: _buildAppBarLeading(context),
        title: Text(widget.title),
        actions: widget.appBarActions,
      ),
      body: AuthRequiredView(
        title: '需要统一认证后继续',
        message: widget.loginDescription,
        buttonLabel: '登录统一认证',
        onAction: () => _presentLoginPrompt(force: true),
        icon: Icons.account_balance_outlined,
      ),
    );
  }
}
