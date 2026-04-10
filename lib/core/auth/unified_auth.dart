import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pointycastle/export.dart';

import '../logging/app_logger.dart';
import '../network/cookie_interceptor.dart';
import '../network/dio_client.dart';
import '../network/network_settings.dart';
import '../network/proxy_mode.dart';
import 'credential_store.dart';

bool isUnifiedAuthLoginEntryUrl(String currentUrl) {
  final raw = currentUrl.trim();
  if (raw.isEmpty) return false;

  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if (host.isEmpty) return path.contains('/cas/login');
  if (host != 'newca.zjxu.edu.cn') return false;
  return path.contains('/cas/login');
}

bool isUnifiedAuthAuthenticatedUrl(String currentUrl) {
  final raw = currentUrl.trim();
  if (raw.isEmpty) return false;

  final uri = Uri.tryParse(raw);
  if (uri == null) return false;
  if (isUnifiedAuthLoginEntryUrl(currentUrl)) return false;

  final host = uri.host.toLowerCase();
  final path = uri.path.toLowerCase();
  if (host.isEmpty) {
    return path.contains('/casclient/login');
  }
  if (host == 'newca.zjxu.edu.cn') {
    return path.contains('/casclient/login');
  }
  return host == 'mobilehall.zjxu.edu.cn' ||
      host == 'app.xiaoyuan.ccb.com' ||
      host == 'libapp.zjxu.edu.cn';
}

String? extractUnifiedAuthServiceUrl(String currentUrl) {
  final raw = currentUrl.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null || !isUnifiedAuthLoginEntryUrl(raw)) return null;

  final serviceUrl = uri.queryParameters['service']?.trim();
  if (serviceUrl == null || serviceUrl.isEmpty) return null;
  return serviceUrl;
}

bool looksLikeUnifiedAuthLoginHtml(String html) {
  final normalizedHtml = html.toLowerCase();
  if (normalizedHtml.isEmpty) return false;
  return normalizedHtml.contains('id="fm1"') ||
      normalizedHtml.contains("id='fm1'") ||
      normalizedHtml.contains('name="execution"') ||
      normalizedHtml.contains("name='execution'") ||
      normalizedHtml.contains('name="lt"') ||
      normalizedHtml.contains("name='lt'") ||
      normalizedHtml.contains('/cas/captcha.html') ||
      normalizedHtml.contains('统一身份认证');
}

sealed class UnifiedAuthLoginResult {}

class UnifiedAuthLoginSuccess extends UnifiedAuthLoginResult {}

class UnifiedAuthLoginFailure extends UnifiedAuthLoginResult {
  UnifiedAuthLoginFailure(this.message);

  final String message;
}

class UnifiedAuthCaptchaException implements Exception {
  UnifiedAuthCaptchaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _UnifiedAuthLoginContext {
  const _UnifiedAuthLoginContext({
    required this.serviceUrl,
    required this.lt,
    required this.execution,
    required this.actionUri,
  });

  final String serviceUrl;
  final String lt;
  final String execution;
  final Uri actionUri;
}

class UnifiedAuthService extends ChangeNotifier {
  UnifiedAuthService._();
  static final UnifiedAuthService instance = UnifiedAuthService._();

  static Future<bool> checkDirectReachable() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      AppLogger.instance.debug('正在测试统一认证直连...');
      final resp = await dio.get<String>(
        '$_newcaOrigin/cas/login',
        queryParameters: {'service': defaultServiceUrl},
      );
      final statusCode = resp.statusCode ?? 0;
      final reachable = statusCode > 0 && statusCode < 500;
      AppLogger.instance.info(
        '统一认证直连: ${reachable ? "可达" : "不可达"} ($statusCode)',
      );
      return reachable;
    } catch (e) {
      AppLogger.instance.info('统一认证直连不可达: $e');
      return false;
    }
  }

  static Future<bool> checkWebVpnReachable() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      AppLogger.instance.debug('正在测试统一认证 WebVPN 连通性...');
      final resp = await dio.get<String>('$_webVpnOrigin/login');
      final reachable = resp.statusCode != null && resp.statusCode! < 400;
      AppLogger.instance.info('统一认证 WebVPN: ${reachable ? "可达" : "不可达"}');
      return reachable;
    } catch (e) {
      AppLogger.instance.info('统一认证 WebVPN 不可达: $e');
      return false;
    }
  }

  static const defaultServiceUrl =
      'https://newca.zjxu.edu.cn/casClient/login/ydd';

  static const _newcaOrigin = 'https://newca.zjxu.edu.cn';
  static const _serviceHallOrigin = 'https://mobilehall.zjxu.edu.cn';
  static const _paymentOrigin = 'https://app.xiaoyuan.ccb.com';
  static const _libraryOrigin = 'https://libapp.zjxu.edu.cn';
  static const _webVpnOrigin = 'https://webvpn.zjxu.edu.cn';
  static const _aesKey = 'key_value_123456';
  static const _aesIv = '0987654321123456';
  static const _requestTimeout = Duration(seconds: 12);

  CookieManager? _cookieManager;

  Dio get _dio => DioClient.instance.dio;
  PersistCookieJar get _cookieJar => DioClient.instance.cookieJar;

  _UnifiedAuthLoginContext? _cachedContext;
  bool _sessionActive = false;
  String? currentAccount;
  Future<void>? _cookieSyncFuture;

  bool get isLoggedIn => _sessionActive;

  Future<bool> prepareLogin({String serviceUrl = defaultServiceUrl}) async {
    if (_sessionActive) return true;
    final context = await _refreshLoginContext(serviceUrl);
    return _sessionActive && context.lt.isEmpty && context.execution.isEmpty;
  }

  Future<bool?> validateSession({
    String serviceUrl = defaultServiceUrl,
    bool syncWebViewCookies = true,
  }) async {
    if (!_sessionActive) return false;

    final validator = debugSessionValidator;
    if (validator != null) {
      final result = await validator(serviceUrl);
      if (result == false) {
        markLoggedOut();
      }
      return result;
    }

    await DioClient.instance.ensureInitialized();
    final loginUri = _buildLoginUri(serviceUrl);

    try {
      final response = await _sendWithProxyFallback<String>(
        label: '统一认证会话校验',
        request: (dio) => dio.getUri<String>(
          loginUri,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 1000,
            headers: {'Referer': loginUri.toString()},
          ),
        ),
      );

      final statusCode = response.statusCode ?? 0;
      final location = response.headers.value('location') ?? '';
      final html = response.data ?? '';
      final hasActiveSession = (statusCode == 302 || statusCode == 303)
          ? isUnifiedAuthAuthenticatedUrl(
              _resolveUri(loginUri, location).toString(),
            )
          : !looksLikeUnifiedAuthLoginHtml(html);

      if (!hasActiveSession) {
        AppLogger.instance.info('统一认证会话已失效，标记登出');
        markLoggedOut();
        return false;
      }

      if (location.isNotEmpty) {
        try {
          await _followRedirectChain(loginUri, location);
        } catch (error) {
          AppLogger.instance.debug('统一认证服务会话预热失败: $serviceUrl :: $error');
        }
      }

      final wasSessionActive = _sessionActive;
      _sessionActive = true;
      if (currentAccount != null) {
        await CredentialStore.instance.saveUnifiedAuthSession(currentAccount!);
      }
      if (syncWebViewCookies) {
        unawaited(_syncCookiesToWebViewSafely());
      }
      if (!wasSessionActive) {
        notifyListeners();
      }
      return true;
    } on DioException catch (error) {
      AppLogger.instance.error('统一认证会话校验失败: ${error.type} ${error.message}');
      return null;
    } catch (error) {
      AppLogger.instance.error('统一认证会话校验异常: $error');
      return null;
    }
  }

  Dio _createProxyFallbackDio() {
    final baseOptions = _dio.options;
    final client = Dio(
      BaseOptions(
        baseUrl: baseOptions.baseUrl,
        connectTimeout: baseOptions.connectTimeout,
        receiveTimeout: baseOptions.receiveTimeout,
        sendTimeout: baseOptions.sendTimeout,
        headers: Map<String, dynamic>.from(baseOptions.headers),
        followRedirects: baseOptions.followRedirects,
        validateStatus: baseOptions.validateStatus,
      ),
    );
    client.interceptors.add(buildCookieInterceptor(_cookieJar));
    applyProxyModeToDio(client, ignoreSystemProxy: false);
    return client;
  }

  bool _shouldRetryWithSystemProxy(DioException error) {
    return NetworkSettings.instance.ignoreSystemProxy.value &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError);
  }

  bool _shouldRetryWithSystemProxyForAny(Object error) {
    if (!NetworkSettings.instance.ignoreSystemProxy.value) return false;
    if (error is TimeoutException) return true;
    if (error is DioException) return _shouldRetryWithSystemProxy(error);
    return false;
  }

  Future<Response<T>> _sendWithProxyFallback<T>({
    required String label,
    required Future<Response<T>> Function(Dio dio) request,
  }) async {
    try {
      return await request(_dio).timeout(_requestTimeout);
    } catch (error) {
      if (!_shouldRetryWithSystemProxyForAny(error)) rethrow;
      AppLogger.instance.info('$label 直连失败，尝试通过系统代理重试');
      final fallbackDio = _createProxyFallbackDio();
      try {
        return await request(fallbackDio).timeout(_requestTimeout);
      } finally {
        fallbackDio.close(force: true);
      }
    }
  }

  Future<Uint8List> fetchCaptcha({
    String serviceUrl = defaultServiceUrl,
  }) async {
    await DioClient.instance.ensureInitialized();
    await _ensureLoginContext(serviceUrl);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final referer = _buildLoginUri(serviceUrl).toString();
    final captchaUri = Uri.parse('$_newcaOrigin/cas/captcha.html?t=$timestamp');
    AppLogger.instance.debug('正在获取统一认证验证码...');
    final resp = await _sendWithProxyFallback<List<int>>(
      label: '统一认证验证码',
      request: (dio) => dio.getUri<List<int>>(
        captchaUri,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Referer': referer},
        ),
      ),
    );

    final contentType = resp.headers.value('content-type') ?? '';
    if (contentType.contains('text/html')) {
      AppLogger.instance.info('统一认证验证码返回 HTML，可能服务不可用');
      throw UnifiedAuthCaptchaException('统一认证验证码加载失败，请稍后重试');
    }

    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      throw UnifiedAuthCaptchaException('统一认证验证码为空，请刷新后重试');
    }

    final data = Uint8List.fromList(bytes);
    if (!_isValidImage(data)) {
      AppLogger.instance.info('统一认证验证码数据非有效图片');
      throw UnifiedAuthCaptchaException('统一认证验证码无效，请刷新后重试');
    }

    AppLogger.instance.info('统一认证验证码获取成功, ${data.length} 字节');
    return data;
  }

  Future<UnifiedAuthLoginResult> login(
    String username,
    String password,
    String captcha, {
    String serviceUrl = defaultServiceUrl,
  }) async {
    try {
      await DioClient.instance.ensureInitialized();
      final context = await _ensureLoginContext(serviceUrl);
      if (context.lt.isEmpty || context.execution.isEmpty) {
        // 如果 session 已经在 _refreshLoginContext 中建立，直接返回成功
        if (_sessionActive) {
          AppLogger.instance.info('统一认证已有有效 session，跳过登录');
          currentAccount = username;
          await CredentialStore.instance.saveUnifiedAuthSession(username);
          notifyListeners();
          return UnifiedAuthLoginSuccess();
        }
        AppLogger.instance.info('统一认证初始化上下文缺失');
        return UnifiedAuthLoginFailure('统一认证初始化失败，请刷新验证码后重试');
      }

      AppLogger.instance.debug('正在加密统一认证密码...');
      final encryptedPassword = _encryptPassword(password);
      final referer = _buildLoginUri(serviceUrl).toString();
      AppLogger.instance.debug('正在发送统一认证登录请求...');
      final response = await _sendWithProxyFallback<String>(
        label: '统一认证登录',
        request: (dio) => dio.postUri<String>(
          context.actionUri,
          data: {
            'username': username,
            'password': encryptedPassword,
            'veriyCode': captcha,
            'lt': context.lt,
            'execution': context.execution,
            '_eventId': 'submit',
          },
          options: Options(
            contentType: 'application/x-www-form-urlencoded',
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 1000,
            headers: {'Referer': referer, 'Origin': _newcaOrigin},
          ),
        ),
      );

      final location = response.headers.value('location') ?? '';
      final html = response.data ?? '';
      if (_isLoginSuccess(response.statusCode, location, html)) {
        await _followRedirectChain(context.actionUri, location);
        unawaited(_syncCookiesToWebViewSafely());
        _sessionActive = true;
        currentAccount = username;
        _cachedContext = null;
        await CredentialStore.instance.saveUnifiedAuthSession(username);
        AppLogger.instance.info('统一认证登录成功，已同步 WebView Cookie');
        notifyListeners();
        return UnifiedAuthLoginSuccess();
      }

      _cachedContext = null;
      final msg = _extractLoginFailureMessage(html);
      AppLogger.instance.info('统一认证登录失败: $msg');
      return UnifiedAuthLoginFailure(msg);
    } on DioException catch (error) {
      _cachedContext = null;
      AppLogger.instance.error('统一认证登录网络异常: ${error.type} ${error.message}');
      return UnifiedAuthLoginFailure('统一认证网络异常：${error.message}');
    } catch (error) {
      _cachedContext = null;
      return UnifiedAuthLoginFailure('统一认证登录失败：$error');
    }
  }

  Future<void> syncCookiesToWebView() async {
    final existing = _cookieSyncFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _syncCookiesToWebViewInternal();
    _cookieSyncFuture = future;
    try {
      await future;
    } finally {
      if (identical(_cookieSyncFuture, future)) {
        _cookieSyncFuture = null;
      }
    }
  }

  Future<void> _syncCookiesToWebViewInternal() async {
    await DioClient.instance.ensureInitialized();
    // loadForRequest 需要带 path 的完整 URI 才能匹配到子路径 cookie
    final uris = [
      Uri.parse('$_newcaOrigin/cas/login'),
      Uri.parse('$_serviceHallOrigin/webroot/decision/view/form'),
      Uri.parse(_paymentOrigin),
      Uri.parse('$_libraryOrigin/Info/Thirdparty/ssoFromDingDing'),
      Uri.parse(_webVpnOrigin),
    ];

    for (final uri in uris) {
      final cookies = await _cookieJar.loadForRequest(uri);
      AppLogger.instance.debug(
        'syncCookies ${uri.host}: ${cookies.map((c) => c.name).join(', ')}',
      );
      for (final cookie in cookies) {
        try {
          await _setWebViewCookie(uri, cookie);
        } catch (error) {
          AppLogger.instance.error(
            '同步 Cookie 失败 ${uri.host}/${cookie.name}: $error',
          );
        }
      }
    }
  }

  void markLoggedOut() {
    _sessionActive = false;
    currentAccount = null;
    _cachedContext = null;
    CredentialStore.instance.clearUnifiedAuthSession();
    notifyListeners();
  }

  Future<void> restoreSession({bool syncWebViewCookies = true}) async {
    final account = await CredentialStore.instance.loadUnifiedAuthSession();
    if (account != null) {
      currentAccount = account;
      _sessionActive = true;
      if (syncWebViewCookies) {
        unawaited(_syncCookiesToWebViewSafely());
      }
      notifyListeners();
    }
  }

  Future<void> _syncCookiesToWebViewSafely() async {
    try {
      await syncCookiesToWebView();
    } catch (error) {
      AppLogger.instance.error('统一认证 Cookie 延迟同步失败: $error');
    }
  }

  Future<void> _setWebViewCookie(Uri uri, io.Cookie cookie) async {
    final domain = (cookie.domain ?? '').trim();
    final path = (cookie.path ?? '').trim();
    await (_cookieManager ??= CookieManager.instance()).setCookie(
      url: WebUri('${uri.scheme}://${uri.host}/'),
      name: cookie.name,
      value: cookie.value,
      domain: domain.isNotEmpty ? domain : uri.host,
      path: path.isNotEmpty ? path : '/',
      isSecure: cookie.secure,
      isHttpOnly: cookie.httpOnly,
      expiresDate: cookie.expires?.millisecondsSinceEpoch,
    );
  }

  Future<_UnifiedAuthLoginContext> _ensureLoginContext(
    String serviceUrl,
  ) async {
    final context = _cachedContext;
    if (context != null && context.serviceUrl == serviceUrl) {
      return context;
    }
    return _refreshLoginContext(serviceUrl);
  }

  Future<_UnifiedAuthLoginContext> _refreshLoginContext(
    String serviceUrl,
  ) async {
    if (_sessionActive) {
      AppLogger.instance.debug('统一认证已有活跃会话，跳过网络请求');
      return _UnifiedAuthLoginContext(
        serviceUrl: serviceUrl,
        lt: '',
        execution: '',
        actionUri: _buildLoginUri(serviceUrl),
      );
    }

    await DioClient.instance.ensureInitialized();
    AppLogger.instance.debug('正在刷新统一认证登录上下文...');
    final loginUri = _buildLoginUri(serviceUrl);
    final response = await _sendWithProxyFallback<String>(
      label: '统一认证登录上下文',
      request: (dio) => dio.getUri<String>(
        loginUri,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 1000,
          headers: {'Referer': loginUri.toString()},
        ),
      ),
    );

    // CAS 返回 302 说明已有 session，直接跟随重定向完成认证
    final statusCode = response.statusCode ?? 0;
    final location = response.headers.value('location') ?? '';
    if ((statusCode == 302 || statusCode == 303) && location.isNotEmpty) {
      final lowerLocation = location.toLowerCase();
      if (!lowerLocation.contains('/cas/login')) {
        AppLogger.instance.info('统一认证已有 session，跟随重定向完成认证');
        await _followRedirectChain(loginUri, location);
        unawaited(_syncCookiesToWebViewSafely());
        _sessionActive = true;
        if (currentAccount != null) {
          await CredentialStore.instance.saveUnifiedAuthSession(
            currentAccount!,
          );
        }
        notifyListeners();
        // 返回空上下文，标记已认证
        final context = _UnifiedAuthLoginContext(
          serviceUrl: serviceUrl,
          lt: '',
          execution: '',
          actionUri: loginUri,
        );
        _cachedContext = context;
        return context;
      }
      // 302 回到 /cas/login，需要跟随获取登录页面
      final redirectUrl = _resolveUri(loginUri, location).toString();
      final casResp = await _sendWithProxyFallback<String>(
        label: '统一认证登录页重定向',
        request: (dio) => dio.get<String>(
          redirectUrl,
          options: Options(
            responseType: ResponseType.plain,
            headers: {'Referer': loginUri.toString()},
          ),
        ),
      );
      final html = casResp.data ?? '';
      final lt = _extractHiddenField(html, 'lt');
      final execution = _extractHiddenField(html, 'execution');
      final action = _extractFormAction(html);
      final context = _UnifiedAuthLoginContext(
        serviceUrl: serviceUrl,
        lt: lt,
        execution: execution,
        actionUri: _resolveUri(loginUri, action),
      );
      _cachedContext = context;
      AppLogger.instance.debug(
        '统一认证上下文: lt=${lt.length}字符 execution=${execution.length}字符',
      );
      return context;
    }

    final html = response.data ?? '';
    final lt = _extractHiddenField(html, 'lt');
    final execution = _extractHiddenField(html, 'execution');
    final action = _extractFormAction(html);
    final context = _UnifiedAuthLoginContext(
      serviceUrl: serviceUrl,
      lt: lt,
      execution: execution,
      actionUri: _resolveUri(loginUri, action),
    );
    _cachedContext = context;
    AppLogger.instance.debug(
      '统一认证上下文: lt=${lt.length}字符 execution=${execution.length}字符',
    );
    return context;
  }

  Uri _buildLoginUri(String serviceUrl) {
    return Uri.parse(
      '$_newcaOrigin/cas/login',
    ).replace(queryParameters: {'service': serviceUrl});
  }

  Uri _resolveUri(Uri baseUri, String location) {
    if (location.isEmpty) return baseUri;
    final resolved = Uri.tryParse(location);
    if (resolved == null) return baseUri;
    if (resolved.hasScheme) return resolved;
    return baseUri.resolveUri(resolved);
  }

  Future<void> _followRedirectChain(Uri baseUri, String location) async {
    var nextUri = _resolveUri(baseUri, location);
    for (var i = 0; i < 8; i++) {
      final response = await _sendWithProxyFallback<String>(
        label: '统一认证重定向链',
        request: (dio) => dio.getUri<String>(
          nextUri,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 1000,
            headers: {'Referer': baseUri.toString()},
          ),
        ),
      );

      final redirect = response.headers.value('location') ?? '';
      if (redirect.isEmpty) return;
      nextUri = _resolveUri(nextUri, redirect);
    }
  }

  String _encryptPassword(String password) {
    final keyBytes = Uint8List.fromList(utf8.encode(_aesKey));
    final ivBytes = Uint8List.fromList(utf8.encode(_aesIv));
    final input = Uint8List.fromList(utf8.encode(password));
    final paddedInput = _pkcs7Pad(input, 16);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(keyBytes), ivBytes));

    final output = Uint8List(paddedInput.length);
    for (var offset = 0; offset < paddedInput.length; offset += 16) {
      cipher.processBlock(paddedInput, offset, output, offset);
    }

    final buffer = StringBuffer();
    for (final byte in output) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
    }
    return buffer.toString();
  }

  Uint8List _pkcs7Pad(Uint8List input, int blockSize) {
    final padding = blockSize - (input.length % blockSize);
    return Uint8List.fromList([
      ...input,
      ...List<int>.filled(padding, padding),
    ]);
  }

  bool _isLoginSuccess(int? statusCode, String location, String html) {
    if (statusCode == 302 || statusCode == 303) {
      return isUnifiedAuthAuthenticatedUrl(location);
    }

    final lowerHtml = html.toLowerCase();
    if (looksLikeUnifiedAuthLoginHtml(lowerHtml)) return false;
    return lowerHtml.contains('登录中') ||
        lowerHtml.contains('/oauth/forward/') ||
        lowerHtml.contains('casclient/login');
  }

  String _extractLoginFailureMessage(String html) {
    final match = RegExp(
      r'''id=["']msg["'][^>]*>([\s\S]*?)</[^>]+>''',
      caseSensitive: false,
    ).firstMatch(html);
    final message = _decodeHtmlEntities(
      (match?.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim(),
    );
    if (message.isNotEmpty) return message;

    if (html.contains('验证码')) return '验证码错误或已过期，请刷新后重试';
    if (html.contains('用户名') || html.contains('密码')) {
      return '账号或密码错误，请检查后重试';
    }

    return '统一认证登录失败，请检查账号、密码和验证码';
  }

  String _extractHiddenField(String html, String fieldName) {
    final pattern = RegExp(
      'name=["\']$fieldName["\'][^>]*value=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    return pattern.firstMatch(html)?.group(1)?.trim() ?? '';
  }

  String _extractFormAction(String html) {
    final pattern = RegExp(
      r'''<form[^>]+id=["']fm1["'][^>]+action=["']([^"']+)["']''',
      caseSensitive: false,
    );
    return pattern.firstMatch(html)?.group(1)?.trim() ?? '';
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .trim();
  }

  bool _isValidImage(Uint8List data) {
    if (data.length < 4) return false;
    if (data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47) {
      return true;
    }
    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) return true;
    if (data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) return true;
    return false;
  }

  @visibleForTesting
  Future<bool?> Function(String serviceUrl)? debugSessionValidator;

  @visibleForTesting
  void debugSetSession({required bool active, String? account}) {
    _sessionActive = active;
    currentAccount = active ? account : null;
    if (!active) {
      _cachedContext = null;
    }
  }

  @visibleForTesting
  void debugReset() {
    _cachedContext = null;
    _sessionActive = false;
    currentAccount = null;
    _cookieManager = null;
    _cookieSyncFuture = null;
    debugSessionValidator = null;
  }
}
