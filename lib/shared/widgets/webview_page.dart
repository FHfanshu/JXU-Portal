import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/credential_store.dart';
import '../../core/logging/app_logger.dart';

typedef WebViewLoadStopCallback =
    Future<void> Function(InAppWebViewController controller, String currentUrl);

const _serviceHallHomeUrl =
    'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/portal/home';
const _serviceHallHost = 'mobilehall.zjxu.edu.cn';
const _serviceHallPath = '/mportal/start/index.html';
const _serviceHallHomeFragment = '/business/ydd/portal/home';

enum WebViewQuickFillKind { zhengfang, unifiedAuth }

WebViewQuickFillKind? detectWebViewQuickFillKind(String currentUrl) {
  final normalizedUrl = currentUrl.trim().toLowerCase();
  if (normalizedUrl.isEmpty) return null;
  if (normalizedUrl.contains('/xtgl/login_slogin.html')) {
    return WebViewQuickFillKind.zhengfang;
  }
  if (normalizedUrl.contains('/cas/login')) {
    return WebViewQuickFillKind.unifiedAuth;
  }
  return null;
}

String selectLoadedWebViewUrl({
  required String fallbackUrl,
  String? reportedUrl,
  String? controllerUrl,
}) {
  for (final candidate in [controllerUrl, reportedUrl, fallbackUrl]) {
    final value = candidate?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool isServiceHallHomeUrl(String currentUrl) {
  final raw = currentUrl.trim();
  if (raw.isEmpty) return false;

  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (uri.host.toLowerCase() != _serviceHallHost ||
      uri.path != _serviceHallPath) {
    return false;
  }

  final fragment = uri.fragment.trim();
  if (fragment.isEmpty) return false;

  final fragmentPath =
      '/${fragment.split('?').first.replaceFirst(RegExp(r'^/+'), '')}';
  return fragmentPath == _serviceHallHomeFragment;
}

/// Reusable full-screen WebView page with progress bar and error handling.
class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.title,
    required this.url,
    this.initialHeaders = const {},
    this.onLoadStop,
    this.enableLoginQuickFill = false,
    this.preferWebViewBackNavigation = false,
    this.onHomePressed,
    this.appBarActions = const [],
  });

  final String title;
  final String url;
  final Map<String, String> initialHeaders;
  final WebViewLoadStopCallback? onLoadStop;
  final bool enableLoginQuickFill;
  final bool preferWebViewBackNavigation;
  final VoidCallback? onHomePressed;
  final List<Widget> appBarActions;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  double _progress = 0;
  bool _hasError = false;
  bool _hasShownEnvHint = false;
  bool _hasFallbackToHome = false;
  bool _allowRoutePop = false;
  late String _currentUrl;
  InAppWebViewController? _controller;
  (String, String)? _savedZhengfangCredentials;
  (String, String)? _savedUnifiedCredentials;
  WebViewQuickFillKind? _quickFillKind;
  bool _quickFillBusy = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    if (widget.enableLoginQuickFill) {
      _restoreSavedCredentials();
      _quickFillKind = detectWebViewQuickFillKind(widget.url);
    }
  }

  void _trackCurrentUrlValue(String? value) {
    if (value == null || value.isEmpty) return;

    _currentUrl = value;
    if (!widget.enableLoginQuickFill) return;

    final nextKind = detectWebViewQuickFillKind(value);
    if (nextKind != _quickFillKind && mounted) {
      setState(() => _quickFillKind = nextKind);
    } else {
      _quickFillKind = nextKind;
    }
  }

  void _trackCurrentUrl(WebUri? url) {
    _trackCurrentUrlValue(url?.toString());
  }

  Future<String> _resolveLoadedUrl(
    InAppWebViewController controller,
    WebUri? reportedUrl,
  ) async {
    final reportedValue = reportedUrl?.toString();
    try {
      final controllerValue = (await controller.getUrl())?.toString();
      final resolved = selectLoadedWebViewUrl(
        fallbackUrl: _currentUrl,
        reportedUrl: reportedValue,
        controllerUrl: controllerValue,
      );
      if (reportedValue != null &&
          reportedValue.isNotEmpty &&
          controllerValue != null &&
          controllerValue.isNotEmpty &&
          reportedValue != controllerValue) {
        AppLogger.instance.debug(
          'WebView load stop URL 修正: reported=$reportedValue actual=$controllerValue',
        );
      }
      return resolved;
    } catch (error) {
      AppLogger.instance.debug('获取 WebView 当前 URL 失败：$error');
      return selectLoadedWebViewUrl(
        fallbackUrl: _currentUrl,
        reportedUrl: reportedValue,
      );
    }
  }

  Future<void> _restoreSavedCredentials() async {
    final zhengfangCredentials = await CredentialStore.instance
        .loadCredentials();
    final unifiedCredentials = await CredentialStore.instance
        .loadUnifiedAuthCredentials();
    if (!mounted) return;

    setState(() {
      _savedZhengfangCredentials = zhengfangCredentials;
      _savedUnifiedCredentials = unifiedCredentials;
    });
  }

  void _showHint(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _goBackInWebViewIfPossible() async {
    final controller = _controller;
    if (controller == null || _hasError) return false;

    try {
      final canGoBack = await controller.canGoBack();
      if (!canGoBack) return false;
      await controller.goBack();
      return true;
    } catch (error) {
      AppLogger.instance.debug('WebView 返回上一页失败：$_currentUrl :: $error');
      return false;
    }
  }

  Future<bool> _handleWillPop() async {
    if (widget.onHomePressed != null && isServiceHallHomeUrl(_currentUrl)) {
      widget.onHomePressed!.call();
      return false;
    }

    if (!widget.preferWebViewBackNavigation) return true;
    final handled = await _goBackInWebViewIfPossible();
    return !handled;
  }

  Future<void> _handleBackPressed() async {
    final shouldPopRoute = await _handleWillPop();
    if (!shouldPopRoute || !mounted) return;
    await _popRoute();
  }

  Future<void> _popRoute() async {
    if (!mounted) return;

    setState(() => _allowRoutePop = true);
    final didPop = await Navigator.of(context).maybePop();
    if (mounted && !didPop) {
      setState(() => _allowRoutePop = false);
    }
  }

  Future<void> _reloadCurrentPage() async {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _progress = 0;
      });
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.reload();
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _hasError = false;
        _controller = null;
        _progress = 0;
      });
    }
  }

  void _fallbackToServiceHallHome(
    InAppWebViewController controller,
    String hint,
  ) {
    _hasFallbackToHome = true;
    _showHint(hint);
    controller.loadUrl(
      urlRequest: URLRequest(url: WebUri(_serviceHallHomeUrl)),
    );
  }

  void _handleConsoleMessage(
    InAppWebViewController controller,
    ConsoleMessage consoleMessage,
  ) {
    final message = consoleMessage.message;
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('dingtalk bridge')) {
      return;
    }

    if (!_hasShownEnvHint && lowerMessage.contains('notindingtalk')) {
      _hasShownEnvHint = true;
      AppLogger.instance.info('WebView 环境提示：$_currentUrl 需要钉钉环境');
      _showHint('当前页面依赖钉钉环境，部分功能可能受限');
      return;
    }

    final errorLike =
        consoleMessage.messageLevel == ConsoleMessageLevel.ERROR ||
        consoleMessage.messageLevel == ConsoleMessageLevel.WARNING ||
        lowerMessage.contains('error') ||
        lowerMessage.contains('exception') ||
        lowerMessage.contains('failed');

    if (errorLike) {
      AppLogger.instance.error(
        'WebView console [${consoleMessage.messageLevel}] $_currentUrl :: $message',
      );
    }
  }

  Future<void> _inspectLoadedPage(InAppWebViewController controller) async {
    try {
      final snapshot = await controller.evaluateJavascript(
        source: '''
        (() => {
          const title = document.title || '';
          const readyState = document.readyState || '';
          const bodyText = document.body?.innerText?.trim() || '';
          const childCount = document.body?.children?.length || 0;
          return {
            title,
            readyState,
            textLength: bodyText.length,
            childCount,
          };
        })();
      ''',
      );

      final map = snapshot is Map
          ? Map<Object?, Object?>.from(snapshot)
          : const {};
      final title = '${map['title'] ?? ''}'.trim();
      final readyState = '${map['readyState'] ?? ''}'.trim();
      final textLength = int.tryParse('${map['textLength'] ?? 0}') ?? 0;
      final childCount = int.tryParse('${map['childCount'] ?? 0}') ?? 0;

      AppLogger.instance.info(
        'WebView load stop: url=$_currentUrl readyState=$readyState title=${title.isEmpty ? '[empty]' : title} textLength=$textLength childCount=$childCount',
      );

      final isBlankLike =
          textLength == 0 && childCount == 0 && readyState == 'complete';
      if (!isBlankLike) return;

      AppLogger.instance.error('WebView 疑似白屏：url=$_currentUrl');

      final uri = Uri.tryParse(_currentUrl);
      final isServiceHallEntry =
          uri != null &&
          uri.host.toLowerCase() == _serviceHallHost &&
          uri.path == '/mportal/start/index.html' &&
          uri.fragment.isEmpty;

      if (isServiceHallEntry && !_hasFallbackToHome) {
        _fallbackToServiceHallHome(controller, '服务大厅入口未渲染，已尝试切换到首页');
      }
    } catch (error) {
      AppLogger.instance.debug('WebView 页面快照失败：$_currentUrl :: $error');
    }
  }

  Future<void> _fillSavedCredentials({
    required bool fillUsername,
    required bool fillPassword,
  }) async {
    final controller = _controller;
    final kind = _quickFillKind;
    if (controller == null || kind == null || _quickFillBusy) return;

    final credentials = switch (kind) {
      WebViewQuickFillKind.zhengfang => _savedZhengfangCredentials,
      WebViewQuickFillKind.unifiedAuth => _savedUnifiedCredentials,
    };

    if (credentials == null) {
      final loginType = kind == WebViewQuickFillKind.zhengfang ? '教务' : '一卡通';
      _showHint('还没有记住$loginType账号密码，请先用应用内登录一次');
      return;
    }

    setState(() => _quickFillBusy = true);

    final username = jsonEncode(fillUsername ? credentials.$1 : '');
    final password = jsonEncode(fillPassword ? credentials.$2 : '');
    final script = switch (kind) {
      WebViewQuickFillKind.zhengfang =>
        '''
(() => {
  const setInputValue = (selectors, value) => {
    if (!value) return false;
    for (const selector of selectors) {
      const input = document.querySelector(selector);
      if (!input) continue;
      input.focus();
      input.value = value;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    }
    return false;
  };

  return {
    usernameFilled: setInputValue(['#yhm', 'input[name="yhm"]'], $username),
    passwordFilled: setInputValue(
      ['#mm', 'input[name="mm"]', 'input[type="password"]'],
      $password
    ),
  };
})()
''',
      WebViewQuickFillKind.unifiedAuth =>
        '''
(() => {
  const setInputValue = (selectors, value) => {
    if (!value) return false;
    for (const selector of selectors) {
      const input = document.querySelector(selector);
      if (!input) continue;
      input.focus();
      input.value = value;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    }
    return false;
  };

  return {
    usernameFilled: setInputValue(['#username', 'input[name="username"]'], $username),
    passwordFilled: setInputValue(
      ['#password', 'input[name="password"]', 'input[type="password"]'],
      $password
    ),
  };
})()
''',
    };

    try {
      final result = await controller.evaluateJavascript(source: script);
      final resultMap = result is Map
          ? Map<Object?, Object?>.from(result)
          : const {};
      final usernameFilled = '${resultMap['usernameFilled']}' == 'true';
      final passwordFilled = '${resultMap['passwordFilled']}' == 'true';

      if (!mounted) return;

      if ((fillUsername && !usernameFilled) ||
          (fillPassword && !passwordFilled)) {
        _showHint('当前登录页字段未识别到，请手动输入');
      } else {
        _showHint(
          kind == WebViewQuickFillKind.zhengfang ? '已填充教务账号密码' : '已填充一卡通账号密码',
        );
      }
    } catch (error) {
      AppLogger.instance.error('WebView 快速填充失败: $_currentUrl :: $error');
      _showHint('快速填充失败，请手动输入');
    } finally {
      if (mounted) {
        setState(() => _quickFillBusy = false);
      } else {
        _quickFillBusy = false;
      }
    }
  }

  Widget _buildQuickFillBar() {
    if (!widget.enableLoginQuickFill || _quickFillKind == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final kind = _quickFillKind!;
    final credentials = kind == WebViewQuickFillKind.zhengfang
        ? _savedZhengfangCredentials
        : _savedUnifiedCredentials;
    final title = kind == WebViewQuickFillKind.zhengfang ? '教务快速填充' : '一卡通快速填充';
    final description = credentials == null
        ? '还没有记住账号密码，先用应用内登录一次后这里会自动复用'
        : '检测到已保存账号密码，可一键填入当前网页登录表单';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            if (credentials != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _quickFillBusy
                        ? null
                        : () => _fillSavedCredentials(
                            fillUsername: true,
                            fillPassword: true,
                          ),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('一键填充'),
                  ),
                  OutlinedButton(
                    onPressed: _quickFillBusy
                        ? null
                        : () => _fillSavedCredentials(
                            fillUsername: true,
                            fillPassword: false,
                          ),
                    child: const Text('填账号'),
                  ),
                  OutlinedButton(
                    onPressed: _quickFillBusy
                        ? null
                        : () => _fillSavedCredentials(
                            fillUsername: false,
                            fillPassword: true,
                          ),
                    child: const Text('填密码'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPopRoute = Navigator.of(context).canPop();
    final showHomeButton = widget.onHomePressed != null;
    final shouldInterceptRoutePop =
        widget.preferWebViewBackNavigation || showHomeButton;
    final useHomeBackButton =
        showHomeButton && isServiceHallHomeUrl(_currentUrl);
    final useWebViewBackButton =
        widget.preferWebViewBackNavigation && !useHomeBackButton;
    final showRouteBackButton =
        !useHomeBackButton && !useWebViewBackButton && canPopRoute;
    final hasCustomLeading =
        useHomeBackButton ||
        useWebViewBackButton ||
        showRouteBackButton ||
        showHomeButton;
    final leadingButtonCount = [
      if (useHomeBackButton || useWebViewBackButton || showRouteBackButton)
        true,
      if (showHomeButton) true,
    ].length;

    return PopScope<void>(
      canPop: !shouldInterceptRoutePop || _allowRoutePop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _allowRoutePop || !shouldInterceptRoutePop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !hasCustomLeading,
          leadingWidth: hasCustomLeading ? leadingButtonCount * 48 : null,
          leading: hasCustomLeading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (useHomeBackButton)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: '返回主页',
                        onPressed: widget.onHomePressed,
                      )
                    else if (useWebViewBackButton)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _handleBackPressed,
                      )
                    else if (showRouteBackButton)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _handleBackPressed,
                      ),
                    if (showHomeButton)
                      IconButton(
                        icon: const Icon(Icons.home_outlined),
                        tooltip: '返回主页',
                        onPressed: widget.onHomePressed,
                      ),
                  ],
                )
              : null,
          title: Text(widget.title),
          actions: [
            ...widget.appBarActions,
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadCurrentPage,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (_hasError)
                    _buildError()
                  else
                    InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(widget.url),
                        headers: widget.initialHeaders.isEmpty
                            ? null
                            : Map<String, String>.from(widget.initialHeaders),
                      ),
                      initialUserScripts: UnmodifiableListView([
                        UserScript(
                          source: '''
(function() {
  var ddMock = {
    ready: function(cb) { if (typeof cb === 'function') setTimeout(cb, 0); },
    error: function(cb) {},
    config: function() {},
    biz: {
      navigation: {
        setTitle: function() {},
        setRight: function() {},
        close: function() {}
      },
      util: {
        openLink: function(opts) {
          if (opts && opts.url) { window.location.href = opts.url; }
        }
      }
    },
    device: {
      notification: {
        alert: function(opts) {
          if (opts && typeof opts.onSuccess === 'function') opts.onSuccess();
        }
      }
    },
    env: { platform: 'notInDingTalk' },
    version: '7.0.0'
  };
  try {
    Object.defineProperty(window, 'dd', {
      get: function() { return ddMock; },
      set: function() {},
      configurable: false
    });
  } catch(e) {
    window.dd = ddMock;
  }
})();
''',
                          injectionTime:
                              UserScriptInjectionTime.AT_DOCUMENT_START,
                        ),
                      ]),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        useHybridComposition: true,
                        allowsInlineMediaPlayback: true,
                        mixedContentMode:
                            MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                        thirdPartyCookiesEnabled: true,
                        supportMultipleWindows: false,
                        useWideViewPort: true,
                        loadWithOverviewMode: true,
                        applicationNameForUserAgent: ' DingTalk/7.0.0',
                      ),
                      onWebViewCreated: (c) {
                        _controller = c;
                        c.addJavaScriptHandler(
                          handlerName: 'ddReady',
                          callback: (args) => {'success': true},
                        );
                      },
                      onLoadStart: (_, url) {
                        _trackCurrentUrl(url);
                        AppLogger.instance.info(
                          'WebView load start: $_currentUrl',
                        );
                        if (!mounted) return;
                        setState(() {
                          _hasError = false;
                          _progress = 0;
                        });
                      },
                      onLoadStop: (controller, url) async {
                        if (!mounted) return;
                        final resolvedUrl = await _resolveLoadedUrl(
                          controller,
                          url,
                        );
                        _trackCurrentUrlValue(resolvedUrl);

                        // Service hall SSO strips the fragment id= param during redirect.
                        // Detect landing on /wfw without id and reload the original URL.
                        if (widget.url.contains('/business/ydd/wfw/id=') &&
                            _currentUrl.contains('/business/ydd/wfw') &&
                            !_currentUrl.contains('/id=')) {
                          await controller.loadUrl(
                            urlRequest: URLRequest(url: WebUri(widget.url)),
                          );
                          return;
                        }

                        await _inspectLoadedPage(controller);

                        final callback = widget.onLoadStop;
                        if (callback != null) {
                          await callback(controller, _currentUrl);
                        }
                      },
                      onUpdateVisitedHistory: (_, url, _) =>
                          _trackCurrentUrl(url),
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                            final uri = navigationAction.request.url?.uriValue;
                            if (uri == null) {
                              return NavigationActionPolicy.ALLOW;
                            }

                            final scheme = uri.scheme.toLowerCase();
                            if (scheme == 'http' || scheme == 'https') {
                              return NavigationActionPolicy.ALLOW;
                            }

                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                            return NavigationActionPolicy.CANCEL;
                          },
                      onConsoleMessage: (controller, consoleMessage) {
                        _handleConsoleMessage(controller, consoleMessage);
                      },
                      onProgressChanged: (_, p) {
                        if (!mounted) return;
                        setState(() => _progress = p / 100);
                      },
                      onReceivedHttpError: (_, request, response) {
                        if (!(request.isForMainFrame ?? false)) return;

                        AppLogger.instance.error(
                          'WebView HTTP 错误: ${response.statusCode} ${response.reasonPhrase ?? ''} url=${request.url}',
                        );

                        if (!mounted) return;
                        setState(() {
                          _hasError = true;
                          _controller = null;
                          _progress = 0;
                        });
                      },
                      onReceivedError: (_, request, error) {
                        if (!(request.isForMainFrame ?? false)) return;

                        AppLogger.instance.error(
                          'WebView 加载失败: code=${error.type} desc=${error.description} url=${request.url}',
                        );

                        if (!mounted) return;
                        setState(() {
                          _hasError = true;
                          _controller = null;
                          _progress = 0;
                        });
                      },
                    ),
                  if (_progress < 1 && !_hasError)
                    LinearProgressIndicator(value: _progress),
                ],
              ),
            ),
            _buildQuickFillBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('页面加载失败'),
          const SizedBox(height: 12),
          FilledButton(onPressed: _reloadCurrentPage, child: const Text('重试')),
        ],
      ),
    );
  }
}
