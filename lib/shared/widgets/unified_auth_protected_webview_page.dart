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
      final retryUrl =
          extractUnifiedAuthServiceUrl(currentUrl) ??
          (currentUrl.trim().isNotEmpty ? currentUrl : widget.url);
      AppLogger.instance.debug('Cookie 重同步完成，重新加载 WebView: $retryUrl');
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(retryUrl)));
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
        title: widget.title,
        url: widget.url,
        onLoadStop: _handleLoadStop,
        onNavigationRequest: widget.onNavigationRequest,
        emulateDingTalkEnvironment: widget.emulateDingTalkEnvironment,
        preferWebViewBackNavigation: widget.preferWebViewBackNavigation,
        onHomePressed: widget.onHomePressed,
        appBarActions: widget.appBarActions,
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.onHomePressed == null,
        leadingWidth: _appBarLeadingWidth(context),
        leading: _buildAppBarLeading(context),
        title: Text(widget.title),
        actions: widget.appBarActions,
      ),
      body: UnifiedAuthLoginWidget(
        serviceUrl: widget.serviceUrl,
        title: '登录统一认证',
        description: widget.loginDescription,
        onLoginSuccess: _onLoginSuccess,
      ),
    );
  }
}
