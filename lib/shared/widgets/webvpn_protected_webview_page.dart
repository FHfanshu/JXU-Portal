import 'package:flutter/material.dart';

import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import 'webview_page.dart';

class WebVpnProtectedWebViewPage extends StatefulWidget {
  const WebVpnProtectedWebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.preferWebViewBackNavigation = false,
    this.onHomePressed,
    this.appBarActions = const [],
  });

  final String title;
  final String url;
  final bool preferWebViewBackNavigation;
  final VoidCallback? onHomePressed;
  final List<Widget> appBarActions;

  @override
  State<WebVpnProtectedWebViewPage> createState() =>
      _WebVpnProtectedWebViewPageState();
}

class _WebVpnProtectedWebViewPageState
    extends State<WebVpnProtectedWebViewPage> {
  bool _preparingSession = true;

  @override
  void initState() {
    super.initState();
    _prepareWebViewSession();
  }

  Future<void> _prepareWebViewSession() async {
    try {
      await ZhengfangAuth.instance.syncWebVpnCookiesToWebView();
    } catch (error) {
      AppLogger.instance.error('准备 WebVPN WebView 会话失败: $error');
    }

    if (!mounted) return;
    setState(() => _preparingSession = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_preparingSession) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: widget.appBarActions,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WebViewPage(
      title: widget.title,
      url: ZhengfangAuth.instance.buildWebVpnProxyUrl(widget.url),
      enableLoginQuickFill: true,
      preferWebViewBackNavigation: widget.preferWebViewBackNavigation,
      onHomePressed: widget.onHomePressed,
      appBarActions: widget.appBarActions,
    );
  }
}
