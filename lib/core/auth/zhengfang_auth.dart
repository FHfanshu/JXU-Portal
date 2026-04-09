import 'dart:convert';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pointycastle/export.dart';

import '../logging/app_logger.dart';
import '../network/dio_client.dart';
import 'credential_store.dart';

bool isZhengfangGatewayLoginUrl(String currentUrl) {
  final raw = currentUrl.trim();
  if (raw.isEmpty) return false;

  final uri = Uri.tryParse(raw);
  if (uri == null) return false;

  return uri.host.toLowerCase() == 'webvpn.zjxu.edu.cn' &&
      uri.path.toLowerCase() == '/login';
}

bool isZhengfangLoginEntryUrl(String currentUrl) {
  final normalizedUrl = currentUrl.trim().toLowerCase();
  if (normalizedUrl.isEmpty) return false;
  return normalizedUrl.contains('/xtgl/login_slogin.html') ||
      normalizedUrl.contains('/cas/login') ||
      isZhengfangGatewayLoginUrl(currentUrl);
}

bool isZhengfangAuthenticatedUrl(String currentUrl) {
  final normalizedUrl = currentUrl.trim().toLowerCase();
  if (normalizedUrl.isEmpty) return false;
  return normalizedUrl.contains('index_initmenu') ||
      normalizedUrl.contains('index_cxyhxxindex') ||
      normalizedUrl.contains('/xtgl/index');
}

/// 教务系统连接模式
enum ZhengfangMode {
  /// 直连教务系统 (校园网)
  direct,

  /// 通过 WebVPN 连接 (非校园网)
  webVpn,
}

sealed class LoginResult {}

class LoginSuccess extends LoginResult {}

class LoginFailure extends LoginResult {
  final String message;
  LoginFailure(this.message);
}

/// Thrown when captcha loading fails due to network or server issues.
class CaptchaException implements Exception {
  final String message;
  CaptchaException(this.message);

  @override
  String toString() => message;
}

/// WebVPN CAS 认证结果
sealed class WebVpnCasResult {}

class WebVpnCasSuccess extends WebVpnCasResult {}

class WebVpnCasFailure extends WebVpnCasResult {
  WebVpnCasFailure(this.message);
  final String message;
}

class ZhengfangAuth extends ChangeNotifier {
  ZhengfangAuth._();
  static final ZhengfangAuth instance = ZhengfangAuth._();

  static const _directOrigin = 'https://jwzx.zjxu.edu.cn';
  static const _directLoginPath = '/jwglxt/xtgl/login_slogin.html';
  static const _directBase = 'https://jwzx.zjxu.edu.cn/jwglxt';

  static const _webVpnBase = 'https://webvpn.zjxu.edu.cn';
  static const _portalPrefix =
      '/http/77726476706e69737468656265737421fae05b84692a62486b468ca88d1b203b';
  static const _webVpnJwglxtPrefix = '$_portalPrefix/jwglxt';
  static const _webVpnLoginPath =
      '$_portalPrefix/jwglxt/xtgl/login_slogin.html';
  static const _directIndexPath = '/jwglxt/xtgl/index_initMenu.html';

  /// WebVPN CAS 登录路径
  static const _webVpnCasPath = '/login';

  String? _cachedCsrfToken;
  bool _contextIndicatesLoggedIn = false;

  ZhengfangMode _mode = ZhengfangMode.direct;
  ZhengfangMode get mode => _mode;

  bool _sessionActive = false;
  String? currentStudentId;

  Dio get _dio => DioClient.instance.dio;
  PersistCookieJar get _cookieJar => DioClient.instance.cookieJar;

  String get _baseUrl => _mode == ZhengfangMode.direct
      ? _directBase
      : '$_webVpnBase$_webVpnJwglxtPrefix';

  String get _loginPageUrl => _mode == ZhengfangMode.direct
      ? '$_directOrigin$_directLoginPath'
      : '$_webVpnBase$_webVpnLoginPath';

  String get _origin =>
      _mode == ZhengfangMode.direct ? _directOrigin : _webVpnBase;

  String get academicServiceUrl => buildPortalUrl(
    '/xtgl/index_initMenu.html',
    queryParameters: {'jsdm': 'xs'},
  );

  String buildPortalUrl(String path, {Map<String, dynamic>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri.toString();
    }
    return uri
        .replace(
          queryParameters: queryParameters.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
        )
        .toString();
  }

  String resolvePortalUrl(String urlOrPath) {
    final raw = urlOrPath.trim();
    if (raw.isEmpty) return raw;

    final uri = Uri.tryParse(raw);
    if (uri == null) return buildPortalUrl(raw);
    if (!uri.hasScheme) {
      return buildPortalUrl(uri.path, queryParameters: uri.queryParameters);
    }
    if (_mode != ZhengfangMode.webVpn ||
        uri.host.toLowerCase() != 'jwzx.zjxu.edu.cn') {
      return raw;
    }

    return Uri.parse('$_webVpnBase$_portalPrefix${uri.path}')
        .replace(
          queryParameters: uri.queryParameters.isEmpty
              ? null
              : uri.queryParameters,
        )
        .toString();
  }

  // ── RSA encryption ──────────────────────────────────────────────────────────

  String _encryptPassword(
    String password,
    String modulusB64,
    String exponentB64,
  ) {
    BigInt decodeBigInt(String b64) {
      final bytes = base64.decode(b64);
      return bytes.fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));
    }

    final modulus = decodeBigInt(modulusB64);
    final exponent = decodeBigInt(exponentB64);
    final publicKey = RSAPublicKey(modulus, exponent);

    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final input = Uint8List.fromList(utf8.encode(password));
    final encrypted = cipher.process(input);
    return base64.encode(encrypted);
  }

  // ── Image validation ─────────────────────────────────────────────────────────

  static bool _isValidImage(Uint8List data) {
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

  // ── 连通性检测 ────────────────────────────────────────────────────────────────

  /// 测试直连教务系统是否可达
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
      AppLogger.instance.debug('正在测试教务系统直连...');
      final resp = await dio.get<String>('$_directOrigin$_directLoginPath');
      final statusCode = resp.statusCode ?? 0;

      // 检查是否有重定向到 WebVPN
      final location = resp.headers.value('location') ?? '';
      final isRedirectedToWebVpn = location.contains('webvpn.zjxu.edu.cn');

      if (isRedirectedToWebVpn) {
        AppLogger.instance.info('教务系统直连: 被重定向到 WebVPN，需要 WebVPN 登录');
        return false;
      }

      final reachable =
          statusCode < 400 && statusCode != 302 && statusCode != 303;
      AppLogger.instance.info(
        '教务系统直连: ${reachable ? "可达" : "不可达"} ($statusCode)',
      );
      return reachable;
    } catch (e) {
      AppLogger.instance.info('教务系统直连不可达: $e');
      return false;
    }
  }

  /// 测试 WebVPN 是否可达
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
      AppLogger.instance.debug('正在测试 WebVPN 连通性...');
      final resp = await dio.get<String>('$_webVpnBase$_webVpnCasPath');
      AppLogger.instance.info('WebVPN 连通性: ${resp.statusCode}');
      return resp.statusCode != null && resp.statusCode! < 400;
    } catch (e) {
      AppLogger.instance.info('WebVPN 不可达: $e');
      return false;
    }
  }

  // ── WebVPN CAS 认证 (含验证码) ─────────────────────────────────────────────────

  String? _cachedCasExecution;
  String? _cachedCasLt;
  String? _cachedCasLoginUrl; // 保存重定向后的 CAS 登录 URL
  String? _cachedAesKey; // AES 加密密钥 aes1
  String? _cachedAesIv; // AES 加密 IV akey

  /// 获取 WebVPN CAS 验证码
  Future<Uint8List> fetchWebVpnCasCaptcha() async {
    await DioClient.instance.ensureInitialized();
    AppLogger.instance.debug('正在获取 WebVPN CAS 登录页面...');
    // WebVPN /login 会 302 重定向到 CAS 登录页面，需要跟随重定向
    final loginUri = '$_webVpnBase$_webVpnCasPath';
    final pageResp = await _dio.get<String>(
      loginUri,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false, // 手动处理重定向
        validateStatus: (s) => s != null && s < 400,
        headers: {'Referer': loginUri},
      ),
    );

    // 处理重定向，获取真实的 CAS 登录页面
    var casLoginUrl = pageResp.headers.value('location') ?? '';
    if (casLoginUrl.startsWith('/')) {
      casLoginUrl = '$_webVpnBase$casLoginUrl';
    }
    AppLogger.instance.debug('CAS 登录页面: $casLoginUrl');

    final casResp = await _dio.get<String>(
      casLoginUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': loginUri},
      ),
    );

    final html = casResp.data ?? '';
    _cachedCasExecution = _extractHiddenField(html, 'execution');
    _cachedCasLt = _extractHiddenField(html, 'lt');
    _cachedCasLoginUrl = casLoginUrl; // 保存 CAS 登录 URL

    // CAS 登录页面中的 __vpn_host_crypt_key 不是用于密码加密的
    // 实际加密密钥是 main.js 中的 aes1='key_value_123456'
    _cachedAesKey = 'key_value_123456';
    _cachedAesIv = '0987654321123456';
    AppLogger.instance.debug(
      'WebVPN CAS AES key: ${_cachedAesKey?.substring(0, _cachedAesKey!.length > 10 ? 10 : _cachedAesKey!.length) ?? "null"}..., iv: ${_cachedAesIv?.substring(0, _cachedAesIv!.length > 10 ? 10 : _cachedAesIv!.length) ?? "null"}...',
    );

    AppLogger.instance.debug(
      'WebVPN CAS execution: ${_cachedCasExecution?.length ?? 0} 字符, lt: ${_cachedCasLt?.length ?? 0} 字符',
    );

    final ts = DateTime.now().millisecondsSinceEpoch;
    // 验证码 URL：实际是 /cas/captcha.html，不是 /cas/login/captcha.html
    // 从 CAS 登录页面 path 提取 base 路径
    final casBaseUri = Uri.parse(casLoginUrl);
    final casPath = casBaseUri.path;
    // /cas/login -> /cas
    final casBasePath = casPath.substring(0, casPath.lastIndexOf('/cas/') + 4);
    final captchaUri = Uri(
      scheme: casBaseUri.scheme,
      host: casBaseUri.host,
      path: '$casBasePath/captcha.html',
      queryParameters: {'vpn-1': '', 't': ts.toString()},
    ).toString();
    AppLogger.instance.debug('正在获取 WebVPN CAS 验证码 from: $captchaUri');
    final resp = await _dio.get<List<int>>(
      captchaUri,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Referer': casLoginUrl},
      ),
    );

    final contentType = resp.headers.value('content-type') ?? '';
    if (contentType.contains('text/html')) {
      throw CaptchaException('WebVPN 验证码加载失败，请稍后重试');
    }

    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      throw CaptchaException('WebVPN 验证码数据为空，请重试');
    }

    final data = Uint8List.fromList(bytes);
    if (!_isValidImage(data)) {
      throw CaptchaException('WebVPN 验证码加载失败，请稍后重试');
    }

    AppLogger.instance.info('WebVPN CAS 验证码获取成功, ${data.length} 字节');
    return data;
  }

  /// WebVPN CAS 登录 (一卡通认证，含验证码)
  Future<WebVpnCasResult> loginWebVpnCas(
    String username,
    String password,
    String captcha,
  ) async {
    try {
      await DioClient.instance.ensureInitialized();
      final execution = _cachedCasExecution;
      final lt = _cachedCasLt;
      if (execution == null || execution.isEmpty) {
        return WebVpnCasFailure('WebVPN 登录上下文缺失，请刷新验证码后重试');
      }

      AppLogger.instance.info('正在通过 WebVPN CAS 登录 (一卡通认证)...');
      final loginUri = _cachedCasLoginUrl ?? '$_webVpnBase$_webVpnCasPath';

      final encryptedPassword = _encryptPasswordWithAes(password);

      AppLogger.instance.debug(
        'WebVPN CAS 登录参数: username=$username, veriyCode=$captcha, lt=${lt != null && lt.length > 10 ? lt.substring(0, 10) : lt ?? ""}..., execution=${execution.length > 20 ? execution.substring(0, 20) : execution}...',
      );

      final resp = await _dio.post<String>(
        loginUri,
        data: {
          'username': username,
          'password': encryptedPassword,
          'veriyCode': captcha,
          if (lt != null && lt.isNotEmpty) 'lt': lt,
          'execution': execution,
          '_eventId': 'submit',
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 1000,
          headers: {'Referer': loginUri, 'Origin': _webVpnBase},
        ),
      );

      final statusCode = resp.statusCode;
      final location = resp.headers.value('location') ?? '';
      final html = resp.data ?? '';
      AppLogger.instance.debug(
        'WebVPN CAS 响应: $statusCode, location=$location',
      );

      // 302/303 重定向且不是回到 login 页面 = 成功
      if ((statusCode == 302 || statusCode == 303) && location.isNotEmpty) {
        final lowerLocation = location.toLowerCase();
        if (!lowerLocation.contains('/cas/login')) {
          // 成功，跟随重定向链建立 session
          await _followWebVpnRedirectChain(loginUri, location);
          _cachedCasExecution = null;
          _cachedCasLt = null;
          _cachedCasLoginUrl = null;
          AppLogger.instance.info('WebVPN CAS 认证成功，正在同步 Cookie...');
          await syncWebVpnCookiesToWebView();
          AppLogger.instance.info('WebVPN CAS 认证成功，Cookie 同步完成');
          return WebVpnCasSuccess();
        }
      }

      // 登录失败，检查错误信息
      AppLogger.instance.debug('WebVPN CAS 登录失败 ($statusCode)，检查错误...');
      // 重新提取 execution 以备重试
      final newExec = _extractHiddenField(html, 'execution');
      if (newExec.isNotEmpty) _cachedCasExecution = newExec;

      // 检查错误消息
      final lowerHtml = html.toLowerCase();
      if (lowerHtml.contains('验证码')) {
        return WebVpnCasFailure('验证码错误或已过期，请刷新后重试');
      }
      if (lowerHtml.contains('密码错误') || lowerHtml.contains('用户名或密码错误')) {
        AppLogger.instance.info('WebVPN CAS 一卡通密码错误');
        return WebVpnCasFailure('一卡通账号或密码错误');
      }

      AppLogger.instance.info('WebVPN CAS 认证未知状态: $statusCode');
      return WebVpnCasFailure('WebVPN 登录失败，请检查账号密码和验证码');
    } on DioException catch (e) {
      AppLogger.instance.error('WebVPN CAS 网络异常: ${e.type} ${e.message}');
      return WebVpnCasFailure('网络异常: ${e.message}');
    } catch (e) {
      AppLogger.instance.error('WebVPN CAS 异常: $e');
      return WebVpnCasFailure('登录异常: $e');
    }
  }

  String _extractHiddenField(String html, String fieldName) {
    final pattern = RegExp(
      'name=["\']$fieldName["\'][^>]*value=["\']([^"\']+)["\']',
      caseSensitive: false,
    );
    return pattern.firstMatch(html)?.group(1)?.trim() ?? '';
  }

  /// AES 加密密码
  String _encryptPasswordWithAes(String password) {
    var key = _cachedAesKey;
    var iv = _cachedAesIv;
    if (key == null || iv == null || key.isEmpty || iv.isEmpty) {
      AppLogger.instance.info('AES 密钥为空，使用原始密码');
      return password;
    }

    // 截断到 16 字符 (AES-128 需要)
    if (key.length > 16) key = key.substring(0, 16);
    if (iv.length > 16) iv = iv.substring(0, 16);

    try {
      final keyBytes = Uint8List.fromList(utf8.encode(key));
      final ivBytes = Uint8List.fromList(utf8.encode(iv));
      final input = Uint8List.fromList(utf8.encode(password));

      AppLogger.instance.debug(
        'AES encrypt: key=${keyBytes.length}bytes, iv=${ivBytes.length}bytes, input=${input.length}bytes',
      );

      final paddedInput = _pkcs7Pad(input, 16);
      AppLogger.instance.debug(
        'AES encrypt: paddedInput=${paddedInput.length}bytes',
      );

      final cipher = CBCBlockCipher(AESEngine())
        ..init(true, ParametersWithIV(KeyParameter(keyBytes), ivBytes));

      final output = Uint8List(paddedInput.length);
      for (var offset = 0; offset < paddedInput.length; offset += 16) {
        cipher.processBlock(paddedInput, offset, output, offset);
      }

      AppLogger.instance.debug('AES encrypt: output=${output.length}bytes');

      final buffer = StringBuffer();
      for (final byte in output) {
        buffer.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
      return buffer.toString();
    } catch (e) {
      AppLogger.instance.error('AES 加密失败: $e');
      return password;
    }
  }

  /// PKCS7 填充
  Uint8List _pkcs7Pad(Uint8List input, int blockSize) {
    final padding = blockSize - (input.length % blockSize);
    return Uint8List.fromList([
      ...input,
      ...List<int>.filled(padding, padding),
    ]);
  }

  /// 同步 WebVPN Cookie 到 WebView
  Future<void> syncWebVpnCookiesToWebView() async {
    if (_mode != ZhengfangMode.webVpn) return;
    await DioClient.instance.ensureInitialized();

    final cookieManager = CookieManager.instance();
    final uris = [
      Uri.parse('$_webVpnBase/'),
      Uri.parse(_loginPageUrl),
      Uri.parse('$_webVpnBase$_webVpnJwglxtPrefix/'),
    ];

    for (final uri in uris) {
      try {
        final cookies = await _cookieJar.loadForRequest(uri);
        AppLogger.instance.debug(
          '同步 WebVPN Cookie ${uri.host}: ${cookies.map((c) => c.name).join(', ')}',
        );
        for (final cookie in cookies) {
          final domain = (cookie.domain ?? '').trim();
          await cookieManager.setCookie(
            url: WebUri('${uri.scheme}://${uri.host}/'),
            name: cookie.name,
            value: cookie.value,
            domain: domain.isNotEmpty ? domain : uri.host,
            path: (cookie.path ?? '').trim().isNotEmpty
                ? cookie.path!.trim()
                : '/',
            isSecure: cookie.secure,
            isHttpOnly: cookie.httpOnly,
            expiresDate: cookie.expires?.millisecondsSinceEpoch,
          );
        }
      } catch (e) {
        AppLogger.instance.error('同步 WebVPN Cookie 失败: $e');
      }
    }
  }

  /// 同步直连教务系统 Cookie 到 WebView
  Future<void> syncDirectCookiesToWebView() async {
    if (_mode != ZhengfangMode.direct) return;
    await DioClient.instance.ensureInitialized();

    final cookieManager = CookieManager.instance();
    final uris = [
      Uri.parse('$_directOrigin/'),
      Uri.parse('$_directOrigin$_directLoginPath'),
      Uri.parse('$_directBase/'),
      Uri.parse('$_directOrigin$_directIndexPath?jsdm=xs'),
    ];

    for (final uri in uris) {
      try {
        final cookies = await _cookieJar.loadForRequest(uri);
        await _clearWebViewCookiesForUri(cookieManager, uri, cookies);
        AppLogger.instance.debug(
          '同步教务系统 Cookie ${uri.host}: ${cookies.map((c) => c.name).join(', ')}',
        );
        for (final cookie in cookies) {
          final domain = (cookie.domain ?? '').trim();
          await cookieManager.setCookie(
            url: WebUri('${uri.scheme}://${uri.host}/'),
            name: cookie.name,
            value: cookie.value,
            domain: domain.isNotEmpty ? domain : uri.host,
            path: (cookie.path ?? '').trim().isNotEmpty
                ? cookie.path!.trim()
                : '/',
            isSecure: cookie.secure,
            isHttpOnly: cookie.httpOnly,
            expiresDate: cookie.expires?.millisecondsSinceEpoch,
          );
        }
        final syncedCookies = await cookieManager.getCookies(
          url: WebUri('${uri.scheme}://${uri.host}${uri.path}'),
        );
        AppLogger.instance.debug(
          'WebView 教务 Cookie ${uri.host}: ${syncedCookies.map((c) => c.name).join(', ')}',
        );
      } catch (e) {
        AppLogger.instance.error('同步教务系统 Cookie 失败: $e');
      }
    }
  }

  Future<Map<String, String>> buildWebViewHeaders(String targetUrl) async {
    await DioClient.instance.ensureInitialized();

    final resolvedUrl = resolvePortalUrl(targetUrl);
    final uri = Uri.parse(resolvedUrl);
    final cookies = await _cookieJar.loadForRequest(uri);
    final cookieHeader = cookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
    AppLogger.instance.debug(
      '构建教务 WebView 请求头: ${cookies.map((c) => c.name).join(', ')}',
    );

    return {
      if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
      'Referer': _loginPageUrl,
    };
  }

  /// 同步 Cookie 到 WebView (根据当前模式)
  Future<void> syncCookiesToWebView() async {
    if (_mode == ZhengfangMode.webVpn) {
      await syncWebVpnCookiesToWebView();
    } else {
      await syncDirectCookiesToWebView();
    }
  }

  /// 校验教务会话是否仍然有效。
  /// 返回:
  /// - `true`: 会话有效
  /// - `false`: 会话失效（会自动标记登出）
  /// - `null`: 校验请求失败（网络异常），不变更当前登录态
  Future<bool?> validateSession() async {
    if (!_sessionActive) return false;

    await DioClient.instance.ensureInitialized();
    final indexUrl = '$_baseUrl/xtgl/index_initMenu.html';

    try {
      final response = await _dio.get<String>(
        indexUrl,
        queryParameters: {'jsdm': 'xs'},
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 1000,
          headers: {'Referer': _loginPageUrl},
        ),
      );

      final statusCode = response.statusCode ?? 0;
      final location = response.headers.value('location') ?? '';
      final html = (response.data ?? '').toLowerCase();

      final redirectedToLogin =
          (statusCode == 302 || statusCode == 303) &&
          (location.toLowerCase().contains('login_slogin') ||
              location.toLowerCase().contains('kaptcha') ||
              isZhengfangGatewayLoginUrl(location));
      final loginPageReturned =
          statusCode == 200 && _looksLikeJwLoginPage(html);

      if (redirectedToLogin || loginPageReturned) {
        AppLogger.instance.info('教务会话已失效，自动标记为未登录');
        markLoggedOut();
        return false;
      }

      return true;
    } on DioException catch (e) {
      AppLogger.instance.info('教务会话校验失败（网络异常）: ${e.type} ${e.message}');
      return null;
    } catch (e) {
      AppLogger.instance.info('教务会话校验失败（未知异常）: $e');
      return null;
    }
  }

  bool _looksLikeJwLoginPage(String html) {
    if (html.isEmpty) return false;

    final hasCredentialField =
        html.contains('id="yhm"') ||
        html.contains("id='yhm'") ||
        html.contains('name="yhm"') ||
        html.contains("name='yhm'") ||
        html.contains('id="yzm"') ||
        html.contains("id='yzm'") ||
        html.contains('name="yzm"') ||
        html.contains("name='yzm'");
    final hasLoginHint =
        html.contains('login_slogin') ||
        html.contains('教学管理信息服务平台') ||
        html.contains('用户登录') ||
        html.contains('忘记密码') ||
        html.contains('验证码');

    return hasCredentialField || hasLoginHint;
  }

  /// 跟随 WebVPN CAS 重定向链建立 session
  Future<void> _followWebVpnRedirectChain(
    String referer,
    String location,
  ) async {
    var nextUrl = location;
    if (nextUrl.startsWith('/')) {
      nextUrl = '$_webVpnBase$nextUrl';
    }
    for (var i = 0; i < 8; i++) {
      AppLogger.instance.debug('WebVPN CAS 重定向 [$i]: $nextUrl');
      final resp = await _dio.get<String>(
        nextUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 1000,
          headers: {'Referer': referer},
        ),
      );
      final redirect = resp.headers.value('location') ?? '';
      if (redirect.isEmpty) return;
      nextUrl = redirect;
      if (nextUrl.startsWith('/')) {
        final uri = Uri.parse(referer);
        nextUrl = '${uri.scheme}://${uri.host}$nextUrl';
      }
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// 设置连接模式
  void setMode(ZhengfangMode mode) {
    _mode = mode;
    _cachedCsrfToken = null;
    _contextIndicatesLoggedIn = false;
    DioClient.instance.updateBaseUrl(_baseUrl);
    DioClient.instance
        .ensureInitialized()
        .then((_) => DioClient.instance.updateBaseUrl(_baseUrl))
        .catchError((_) {});
    AppLogger.instance.info(
      '教务系统连接模式切换为: ${mode == ZhengfangMode.direct ? "直连" : "WebVPN"}',
    );
    notifyListeners();
  }

  Future<Uint8List> fetchCaptcha() async {
    await DioClient.instance.ensureInitialized();
    await _refreshLoginContext();
    final ts = DateTime.now().millisecondsSinceEpoch;
    AppLogger.instance.debug(
      '正在获取教务系统验证码 [${_mode == ZhengfangMode.direct ? "直连" : "WebVPN"}]...',
    );
    final resp = await _dio.get<List<int>>(
      '$_baseUrl/kaptcha',
      queryParameters: {'time': ts},
      options: Options(
        responseType: ResponseType.bytes,
        headers: {'Referer': _loginPageUrl},
      ),
    );

    final location = resp.headers.value('location') ?? '';
    if (isZhengfangGatewayLoginUrl(location)) {
      AppLogger.instance.info('教务验证码请求被重定向到 WebVPN 登录页');
      throw CaptchaException('WebVPN 认证已过期，请重新登录');
    }

    final contentType = resp.headers.value('content-type') ?? '';
    if (contentType.contains('text/html')) {
      AppLogger.instance.info('验证码返回 HTML，可能未在校园网环境');
      if (_mode == ZhengfangMode.direct) {
        throw CaptchaException('无法连接到教务系统，请确保在校园网环境或已连接VPN');
      } else {
        throw CaptchaException('WebVPN 认证已过期，请重新登录');
      }
    }

    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      throw CaptchaException('验证码数据为空，请重试');
    }

    final data = Uint8List.fromList(bytes);

    if (!_isValidImage(data)) {
      AppLogger.instance.info('验证码数据非有效图片，可能未在校园网环境');
      if (_mode == ZhengfangMode.direct) {
        throw CaptchaException('无法连接到教务系统，请确保在校园网环境或已连接VPN');
      } else {
        throw CaptchaException('WebVPN 连接异常，请重试');
      }
    }

    AppLogger.instance.info('验证码获取成功, ${data.length} 字节');
    return data;
  }

  Future<LoginResult> login(
    String username,
    String password,
    String captcha,
  ) async {
    try {
      await DioClient.instance.ensureInitialized();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final csrftoken = await _ensureCsrfToken();
      if (csrftoken.isEmpty) {
        if (_contextIndicatesLoggedIn) {
          if (username.isNotEmpty) {
            currentStudentId = username;
            await CredentialStore.instance.saveZhengfangSession(username);
          }
          _sessionActive = true;
          AppLogger.instance.info('检测到教务已有有效会话，跳过登录请求');
          notifyListeners();
          return LoginSuccess();
        }
        return LoginFailure('初始化登录参数失败，请刷新验证码后重试');
      }

      AppLogger.instance.debug('正在获取 RSA 公钥...');
      final keyResp = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/xtgl/login_getPublicKey.html',
        queryParameters: {'time': ts},
        options: Options(
          headers: {
            'Referer': _loginPageUrl,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
      final publicKeyRedirect = keyResp.headers.value('location') ?? '';
      if (isZhengfangGatewayLoginUrl(publicKeyRedirect)) {
        return LoginFailure('WebVPN 认证已过期，请重新登录');
      }
      final modulus = keyResp.data?['modulus'] as String?;
      final exponent = keyResp.data?['exponent'] as String?;
      if (modulus == null ||
          exponent == null ||
          modulus.isEmpty ||
          exponent.isEmpty) {
        return LoginFailure('获取登录公钥失败，请稍后重试');
      }
      AppLogger.instance.debug('公钥获取成功，正在加密密码...');

      final encryptedPwd = _encryptPassword(password, modulus, exponent);

      await _dio.post<void>(
        '$_baseUrl/xtgl/login_logoutAccount.html',
        options: Options(
          headers: {'Referer': _loginPageUrl, 'Origin': _origin},
        ),
      );

      AppLogger.instance.debug('正在发送教务系统登录请求...');
      final loginResp = await _dio.post<String>(
        '$_baseUrl/xtgl/login_slogin.html',
        queryParameters: {'time': ts},
        data: {
          'csrftoken': csrftoken,
          'language': 'zh_CN',
          'yhm': username,
          'mm': encryptedPwd,
          'yzm': captcha,
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 400,
          headers: {'Referer': _loginPageUrl, 'Origin': _origin},
        ),
      );

      final location = loginResp.headers.value('location') ?? '';
      final html = loginResp.data ?? '';
      if (isZhengfangGatewayLoginUrl(location)) {
        AppLogger.instance.info('教务系统登录被重定向到 WebVPN 登录页');
        return LoginFailure('WebVPN 认证已过期，请重新登录');
      }
      if (_isLoginSuccess(loginResp.statusCode, location, html)) {
        currentStudentId = username;
        _sessionActive = true;
        _cachedCsrfToken = null;
        await CredentialStore.instance.saveZhengfangSession(username);
        AppLogger.instance.info(
          '教务系统登录成功 [${_mode == ZhengfangMode.direct ? "直连" : "WebVPN"}]',
        );
        notifyListeners();
        return LoginSuccess();
      }

      final msg = _extractLoginFailureMessage(html);
      AppLogger.instance.info('教务系统登录失败: $msg');
      return LoginFailure(msg);
    } on DioException catch (e) {
      _cachedCsrfToken = null;
      AppLogger.instance.error('教务系统登录网络异常: ${e.type} ${e.message}');
      return LoginFailure('网络错误：${e.message}');
    } catch (e) {
      _cachedCsrfToken = null;
      return LoginFailure('登录异常：$e');
    }
  }

  bool get isLoggedIn => _sessionActive;

  void markLoggedIn() {
    _sessionActive = true;
    if (currentStudentId != null) {
      CredentialStore.instance.saveZhengfangSession(currentStudentId!);
    }
    notifyListeners();
  }

  void markLoggedOut() {
    _sessionActive = false;
    currentStudentId = null;
    _cachedCsrfToken = null;
    _contextIndicatesLoggedIn = false;
    CredentialStore.instance.clearZhengfangSession();
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final studentId = await CredentialStore.instance.loadZhengfangSession();
    if (studentId != null) {
      currentStudentId = studentId;
      _sessionActive = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await DioClient.instance.ensureInitialized();
    try {
      await _dio.post<void>('$_baseUrl/xtgl/login_logoutAccount.html');
    } catch (_) {}
    await _cookieJar.deleteAll();
    _sessionActive = false;
    currentStudentId = null;
    _cachedCsrfToken = null;
    _contextIndicatesLoggedIn = false;
    await CredentialStore.instance.clearZhengfangSession();
    notifyListeners();
  }

  Future<void> _refreshLoginContext() async {
    AppLogger.instance.debug('正在刷新教务系统登录上下文...');
    await _refreshCsrfToken();
  }

  Future<void> _clearWebViewCookiesForUri(
    CookieManager cookieManager,
    Uri uri,
    List<io.Cookie> cookies,
  ) async {
    if (cookies.isEmpty) return;

    final rootUrls = <String>{
      '${uri.scheme}://${uri.host}/',
      if (uri.scheme == 'https') 'http://${uri.host}/',
    };
    final normalizedPath = (uri.path.isEmpty ? '/' : uri.path).trim();

    for (final cookie in cookies) {
      final domain = (cookie.domain ?? '').trim();
      final targetDomain = domain.isNotEmpty ? domain : uri.host;
      final targetPath = (cookie.path ?? '').trim().isNotEmpty
          ? cookie.path!.trim()
          : normalizedPath;

      for (final rootUrl in rootUrls) {
        try {
          await cookieManager.deleteCookie(
            url: WebUri(rootUrl),
            name: cookie.name,
            domain: targetDomain,
            path: '/',
          );
        } catch (_) {}
        try {
          await cookieManager.deleteCookie(
            url: WebUri(rootUrl),
            name: cookie.name,
            domain: targetDomain,
            path: targetPath,
          );
        } catch (_) {}
      }
    }
  }

  Future<String> _ensureCsrfToken() async {
    final token = _cachedCsrfToken?.trim();
    if (token != null && token.isNotEmpty) return token;
    return _refreshCsrfToken();
  }

  Future<String> _refreshCsrfToken() async {
    AppLogger.instance.debug('正在获取 CSRF Token...');
    _contextIndicatesLoggedIn = false;
    final pageResp = await _dio.get<String>(
      '$_baseUrl/xtgl/login_slogin.html',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': _loginPageUrl},
      ),
    );

    final statusCode = pageResp.statusCode ?? 0;
    final location = pageResp.headers.value('location') ?? '';
    if (isZhengfangGatewayLoginUrl(location)) {
      AppLogger.instance.info('检测到 WebVPN 登录页重定向，当前认证已过期');
      markLoggedOut();
      throw CaptchaException('WebVPN 认证已过期，请重新登录');
    }
    if (_isLoginSuccess(statusCode, location, '')) {
      AppLogger.instance.info('检测到 302 重定向到首页，旧会话可能已过期，清除 Cookie 后重新获取登录页');
      await _cookieJar.deleteAll();
      _sessionActive = false;
      _cachedCsrfToken = null;
      notifyListeners();

      final retryResp = await _dio.get<String>(
        '$_baseUrl/xtgl/login_slogin.html',
        options: Options(
          responseType: ResponseType.plain,
          headers: {'Referer': _loginPageUrl},
        ),
      );

      final retryLocation = retryResp.headers.value('location') ?? '';
      if (isZhengfangGatewayLoginUrl(retryLocation)) {
        AppLogger.instance.info('清除 Cookie 后跳转到 WebVPN 登录页，需要重新认证');
        markLoggedOut();
        throw CaptchaException('WebVPN 认证已过期，请重新登录');
      }
      if (_isLoginSuccess(retryResp.statusCode, retryLocation, '')) {
        _sessionActive = true;
        _cachedCsrfToken = null;
        _contextIndicatesLoggedIn = true;
        AppLogger.instance.info('清除 Cookie 后仍检测到有效会话');
        notifyListeners();
        return '';
      }

      final retryHtml = retryResp.data ?? '';
      final retryToken = _extractCsrfFromHtml(retryHtml);
      if (retryToken.isNotEmpty) {
        _cachedCsrfToken = retryToken;
        AppLogger.instance.debug('CSRF Token 重新获取成功: ${retryToken.length} 字符');
        _contextIndicatesLoggedIn = false;
        return retryToken;
      }

      AppLogger.instance.info('清除 Cookie 后仍无法获取 CSRF Token');
      _contextIndicatesLoggedIn = false;
      return '';
    }

    final pageHtml = pageResp.data ?? '';
    final token = _extractCsrfFromHtml(pageHtml);
    _cachedCsrfToken = token;
    if (token.isEmpty) {
      AppLogger.instance.info('CSRF Token 为空，可能连接异常');
      _contextIndicatesLoggedIn = false;
    } else {
      AppLogger.instance.debug('CSRF Token 获取成功: ${token.length} 字符');
      _contextIndicatesLoggedIn = false;
    }
    return token;
  }

  String _extractCsrfFromHtml(String html) {
    final matchById = RegExp(
      r'''id=["']csrftoken["'][^>]*value=["']([^"']+)["']''',
    ).firstMatch(html);
    final matchByName = RegExp(
      r'''name=["']csrftoken["'][^>]*value=["']([^"']+)["']''',
    ).firstMatch(html);
    return (matchById?.group(1) ?? matchByName?.group(1) ?? '').trim();
  }

  bool _isLoginSuccess(int? statusCode, String location, String html) {
    if (statusCode == 302 || statusCode == 303) {
      if (isZhengfangLoginEntryUrl(location)) return false;
      return isZhengfangAuthenticatedUrl(location);
    }
    return html.contains('/xtgl/index_initMenu.html') ||
        html.contains('/xtgl/index_cxYhxxIndex.html');
  }

  String _extractLoginFailureMessage(String html) {
    final tipMatch = RegExp(
      r'''id=["']tips["'][^>]*>([\s\S]*?)</[^>]+>''',
      caseSensitive: false,
    ).firstMatch(html);
    if (tipMatch != null) {
      final message = _decodeHtmlEntities(
        (tipMatch.group(1) ?? '').replaceAll(RegExp(r'<[^>]+>'), '').trim(),
      );
      if (message.isNotEmpty) return message;
    }

    if (html.contains('验证码')) return '验证码错误或已过期，请刷新后重试';
    if (html.contains('用户名') || html.contains('密码')) return '用户名或密码错误';
    return '登录失败，请检查用户名、密码和验证码';
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

  @visibleForTesting
  void debugSetSession({required bool active, String? studentId}) {
    _sessionActive = active;
    currentStudentId = active ? studentId : null;
    if (!active) {
      _cachedCsrfToken = null;
      _contextIndicatesLoggedIn = false;
    }
  }

  @visibleForTesting
  void debugReset() {
    _cachedCsrfToken = null;
    _contextIndicatesLoggedIn = false;
    _sessionActive = false;
    currentStudentId = null;
    _cachedCasExecution = null;
    _cachedCasLt = null;
    _cachedCasLoginUrl = null;
    _cachedAesKey = null;
    _cachedAesIv = null;
    _mode = ZhengfangMode.direct;
  }
}
